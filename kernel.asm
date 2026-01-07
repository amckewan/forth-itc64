; x86 Forth registers
;
; rax = top of stack
; rbx = word pointer (xt)
; rsp = data stack pointer
; rbp = return stack pointer
; r12 = instruction pointer
; r13 = locals pointer
; r14 = user pointer
; r15 = dictionary origin

; rcx, rdx, rsi, rdi, r8-r11 scratch (ebx if not needed)

; Forth register aliases
%define sp rsp
%define rp rbp
%define ip r12
%define lp r13
%define up r14

; Indirect threaded NEXT
; An XT is a 32-bit cell offset from r15 (32 GB max)
; ebx is the word register containing the current XT

%define next_1   mov     ebx,[ip]
%define next_2   add     ip,4
%define next_3   jmp     [r15+rbx*8]

%macro  next    0
        mov     ebx,[ip]               ; NEXT1
        add     ip,4                   ; NEXT2
        jmp     [r15+rbx*8]            ; NEXT3
%endmacro

%macro  code    1
        align   16
%1:
%endmacro

        [map symbols code.map]

        bits    64
        org     1_0000_0000h    ; 4 GB origin (for MacOS)
origin:

; ==========================================================
; System variables shared with the C wrapper.

        dq      cold            ; cold start entry

;warm:           dq      0
;sp0:            dq      0
;rp0:            dq      0
;handler:        dq      0

; ==========================================================
; Variables shared with Forth
; These start at DATA_START (origin + 8K).
; We can reference them as offsets from r15 (origin).

%define CODE_SIZE       2000h

%define COLD_XT         (CODE_SIZE + 0)
%define RP0             (CODE_SIZE + 1 * 8)     ; saved by this code
%define SP0             (CODE_SIZE + 2 * 8)

; ==========================================================
; Linus/MacOS ABI: 6 args passed in RDI, RSI, RDX, RCX, R8, and R9
; Windows ABI: 4 args passed in RCX, RDX, R8, and R9
;
; int cold(u64 memsize, int argc, char *argv[])
; RDI = memsize, RSI = argc, RDX = argv

%define TIB_SIZE 2000h      ; for text input buffers

cold:
        push    rbp     ; save ABI regs
        push    rbx
        push    r12
        push    r13
        push    r14
        push    r15
        mov     rbp,rsp

        mov     r15,origin

;        jmp     forth_return

; Forth RP = rsp (this is RP0)
;        mov     [r15+RP0],rsp
        lea     sp,[r15+rdi-TIB_SIZE]   ; sp = top of memory - #TIBs
;        jmp     forth_return

; run forth
        lea     ip,[r15 + (forth_return_ip - origin)]
        next

        align   4
forth_return_ip:
        dd      (forth_return_cfa - origin) >> 3

        align   8
forth_return_cfa:
        dq      forth_return

code forth_return
        mov     rax,123
        mov     rsp,rbp
;        mov     rsp,[r15+RP0]
        pop     r15
        pop     r14
        pop     r13
        pop     r12
        pop     rbx
        pop     rbp
        ret



; ==================== Runtime for Defining Words ====================

code docreate
        push    rax
        lea     rax,[r15+rbx*8+8]
        next

code doconstant
        push    rax
        mov     rax,[r15+rbx*8+8]
        next

code dodefer
        mov     ebx,[r15+rbx*8+8]       ; pfa contains 32-bit XT
        jmp     [r15+rbx*8]             ; NEXT3

code docolon
        mov     [rp-8],ip             ; save IP
        lea     ip,[r15+rbx*8+12]      ; new IP, NEXT2
        mov     ebx,[r15+rbx*8+8]       ; NEXT1
        sub     rp,8
        jmp     [r15+rbx*8]             ; NEXT3

code unnest
        mov     ip,[rp]
        add     rp,8
        next

code execute
        mov     rbx,rax
        pop     rax
        jmp     [r15+rbx*8]             ; NEXT3


;;;;;;;;;;;;; DOES> ;;;;;;;;;;;;;;
; (;CODE) is followed by a cell offset from r15 (like an XT)
; At that code address is the code for the child to execute.
; The child code pushes the pfa, saves IP on R-stack and sets
; IP to point to the first instruction of the DOES> part.

; (;CODE) changes the code field of the last word defined
; to the address following?.
;
; body of DOES> parent
;       dd      ..some creating code.
;       dd      (;code)
;       dd      child code address (cell offset from origin)
; new IP ->
;       dd      first XT after DOES>
;
; : (;CODE)  R> dw@ cells origin + ( code address )  PATCH ( last ) ;
;
; : DOES>  COMPILE (;CODE)  calign  cp @ dw,
;       ( build code in code space for the children )

; This is the code that is generated for each DOES> parent.
; It is unique since it contains the IP for the DOES> part.
; (;CODE) patches the code field of the last word defined to be this.
; All child words share the same code.

code does_template
        push    rax                     ; push pfa
        lea     rax,[r15+rbx*8+8]

        mov     [rp-8],ip             ; save IP
        sub     rp,8

        mov     ip,qword does1               ; new IP from DOES> parent
        next

; This version reduces the generated code by factoring out the common part.

code does_template2
        mov     rdx,qword does_common   ; common DOES> routine
        mov     rcx,qword does1         ; unique IP from DOES> parent
        jmp     rdx

;   133 00000210 48BA-                           mov     rdx,qword does_common   ; common DOES> routine
;   133 00000212 [3002000000000000] 
;   134 0000021A 49BC-                           mov     ip,qword does1         ; unique IP from DOES> parent
;   134 0000021C [5502000000000000] 
;   135 00000224 FFE2                            jmp     rdx
;
; : {code}  CP @ DP @ CP ! DP ! ; \ swap CP and DP
; : align16  begin  here 15 and while  $90 c,  repeat ;
; : DOES,  {code}  align16  $BA48 w, $100002030 ,  $BC49 w, here ,  $E2FF w,  {code} ;

code does_common
        push    rax                     ; push pfa
        lea     rax,[r15+rbx*8+8]

        mov     [rp-8],ip             ; save IP
        sub     rp,8

        mov     ip,rcx                 ; new IP from DOES> parent
        next

dodoes_parent:
        dd      0               ; ;code
        dd      0               
does1:
        dd      $12345678       ; 1st xt of does> part


; ==================== Local Variables ====================

; local{ ( -- )  build local stack frame
; followed inline by 4 bytes: #locals,#params,0,0

code locals_start
        mov     [rp-8],r14             ; save LP to R-stack
        lea     r14,[rp-8]             ; new LP -> old LP
        lea     rp,[rp-8]

        xor     ecx,ecx
        mov     cl,[ip]                ; locals count
        inc     ip
        jecxz   .nolocs
        xor     rdx,rdx
.locs:  mov     [rp-8],rdx
        sub     rp,8
        loop    .locs
.nolocs:

        mov     cl,[ip]                ; params count
        add     ip,3
        jecxz   .noparams
.params:mov     [rp-8],rax
        sub     rp,8
        pop     rax
        loop    .params
.noparams:
        next

code locals_end
        lea     rp,[lp+8]
        mov     lp,[lp]
        next

code local_fetch    ; inline 4-byte local # (1,2,3, etc.)
        mov     ecx,[ip]       ; zero extend
        add     ip,4
        neg     rcx
        push    rax
        mov     rax,[lp+rcx*8]
        next

code local_store   ; inline 4-byte local # (1,2,3, etc.)
        mov     ecx,[ip]       ; zero extend
        add     ip,4
        neg     rcx
        mov     [lp+rcx*8],rax
        pop     rax
        next

; ==================== Literals ====================

code lit32
        push    rax
        mov     eax,[ip]
        add     ip,4
        cdqe                    ; sign extend eax->rax
        next

code lit64
        push    rax
        mov     rax,[ip]
        add     ip,8
        next

code litq                       ; (")  ( -- str )
        xor     rcx,rcx
        push    rax
        mov     rax,ip          ; top = string address
        mov     cl,[ip]         ; rcx = count
        lea     ip,[ip+1+rcx+3] ; count + chars + padding
        and     ip,-4           ; 4-byte align
        next

; ==================== Branching ====================

code branch
        mov     ecx,[ip]        ; 32-bit signed offset in bytes    
        movsxd  rcx,ecx
        add     ip,rcx
        next

code branch_if_zero
        test    rax,rax
        pop     rax
        jz      branch
        add     ip,4
        next

; ==================== DO...LOOP ====================

; ==================== Stack ====================

code dupe
        push    rax
        next

code drop
        pop     rax
        next

code swap
        xchg    rax,[sp]
        next

code over
        mov     rcx,[sp]
        push    rax
        mov     rax,rcx
        next

code rot
        mov     rcx,[rsp]
        mov     rdx,[rsp+8]
        mov     [rsp],rax
        mov     [rsp+8],rcx
        mov     rax,rdx
        next

code nip
        pop     rcx
        next

code qdup
        test    rax,rax
        jnz     .nodup
        push    rax
.nodup  next

code pick
        mov     rax,[sp+rax*8]
        next

code to_r
        mov     [rp-8],rax
        sub     rp,8
        pop     rax
        next

code r_from
        push    rax
        mov     rax,[rp]
        add     rp,8
        next

code r_at
        push    rax
        mov     rax,[rp]
        next

code rdrop
        add     rp,8    ; needed?
        next

code dup_to_r
        mov     [rp-8],rax
        sub     rp,8
        next

code two_to_r
        pop     rcx
        mov     [rp-16],rax
        pop     rax
        mov     [rp-8],rcx
        sub     rp,16
        next

code two_r_from
        mov     rcx,[rp+8]
        push    rax
        mov     rax,[rp]
        push    rcx
        add     rp,16
        next

code two_r_at
        mov     rcx,[rp+8]
        push    rax
        mov     rax,[rp]
        push    rcx
        next

code two_dup
        mov     rcx,[sp]
        push    rax
        push    rcx
        next

code two_drop
        pop     rax
        pop     rax
        next

code two_swap
        mov     rbx,[sp]
        mov     rcx,[sp+8]
        mov     rdx,[sp+16]
        mov     [sp+16],rbx
        mov     [sp+8],rax
        mov     [sp],rdx
        mov     rax,rcx
        next

code two_over
        mov     rcx,[sp+8]
        mov     rdx,[sp+16]
        push    rax
        push    rdx
        mov     rax,rcx
        next

; ==================== Arithmatic ====================

code plus
        pop     rcx
        add     rax,rcx
        next

code minus
        sub     rax,[sp]
        pop     rcx
        neg     rax
        next

code star
        pop     rcx
        mul     rcx
        next

code slash
        mov     rcx,rax
        pop     rax
        cdq
        idiv    rcx
        next

code um_star                    ; UM* ( n1 n2 -- d )
        pop     rcx
        mul     rcx
        push    rax
        mov     rax,rdx
        next

code um_slash_mod               ; UM/MOD ( ud u -- rem quot )
        mov     rcx,rax
        pop     rdx
        pop     rax
        div     rcx
        push    rdx
        next

code slash_mod                  ; /MOD ( n1 n2 -- rem quot )
        mov     rcx,rax
        pop     rax
        cdq
        idiv    rcx
        push    rdx
        next

code u_slash_mod                ; U/MOD ( n1 n2 -- rem quot )
        mov     rcx,rax
        pop     rax
        xor     rdx,rdx
        div     rcx
        push    rdx
        next

code star_slash_mod             ; */MOD ( n1 n2 n3 -- rem quot )  n1 * n2 / n3
        mov     rcx,rax ; n3
        pop     rbx     ; n2
        pop     rax     ; n1
        imul    rbx
        idiv    rcx
        push    rdx
        next

code negate
        neg     rax
        next

code one_plus
        inc rax
        next

code one_minus
        dec rax
        next

code two_star
        shl     rax,1
        next

code two_slash
        sar     rax,1
        next

; : cells 3 lshift ;
; : cell+  8 + ;
code cells
        shl     rax,3
        next

code cell_plus
        add     rax,8
        next

; ==================== Logic ====================

code andd
        pop     rcx
        and     rax,rcx
        next

code orr
        pop     rcx
        or      rax,rcx
        next

code xorr
        pop     rcx
        xor     rax,rcx
        next

code invert
        not     rax
        next

code lshift
        mov     rcx,rax
        pop     rax
        shl     rax,cl
        next

code rshift
        mov     rcx,rax
        pop     rax
        shr     rax,cl
        next

; ==================== Memory ====================
; @ ! +! C@ C! W@ W! DW@ DW! 2@ 2!

code fetch
        mov     rax,[rax]
        next

code store
        pop     rcx
        mov     [rax],rcx
        pop     rax
        next

code two_fetch
        mov     rcx,[rax+8]
        mov     rax,[rax]
        push    rcx
        next

code two_store
        pop     rcx
        pop     rdx
        mov     [rax],rcx
        mov     [rax+8],rdx
        pop     rax
        next

code plus_store
        pop     rcx
        add     [rax],rcx
        pop     rax
        next

code cfetch
        xor     rcx,rcx
        mov     cl,[rax]
        mov     rax,rcx
        next

code cstore
        pop     rcx
        mov     [rax],cl
        pop     rax
        next

code wfetch
        xor     rcx,rcx
        mov     cx,[rax]
        mov     rax,rcx
        next

code wstore
        pop     rcx
        mov     [rax],cx
        pop     rax
        next

code dwfetch
        mov     eax,[rax]
        next

code dwstore
        pop     rcx
        mov     [rax],ecx
        pop     rax
        next


; ==================== Comparison ====================
; 0= 0< 0> = < > U< U>

code zero_equal
        test    rax,rax
        mov     rax,0
        jnz     .1
        dec     rax
.1:     next

code zero_less
        test    rax,rax
        mov     rax,0
        jns     .1
        dec     rax
.1:     next

code zero_greater
        test    rax,rax
        mov     rax,0
        jle     .1
        dec     rax
.1:     next

code equal
        pop     rcx
        cmp     rcx,rax
        mov     rax,0
        jne     .1
        dec     rax
.1:     next

code less
        pop     rcx
        cmp     rcx,rax
        mov     rax,0
        jge     .1
        dec     rax
.1:      next

code greater
        pop     rcx
        cmp     rcx,rax
        mov     rax,0
        jle     .1
        dec     rax
.1:     next

code uless
        pop     rcx
        cmp     rcx,rax
        mov     rax,0
        jae     .1
        dec     rax
.1:     next

code ugreater
        pop     rcx
        cmp     rcx,rax
        mov     rax,0
        jbe     .1
        dec     rax
.1:     next


; ==================== Strings ====================
; ==================== Block Memory ====================
; ==================== Console I/O ====================
; ==================== File I/O ====================
; ==================== OS Interface ====================

code cmove
        mov     rcx,rax
        pop     rdi
        pop     rsi
        pop     rax
        rep     movsb
        next                    ; interleave

code fill   ; ( addr len char -- )
        pop     rcx
        pop     rdi
        rep     stosb
        pop     rax
        next

code comp ; ( a1 a2 n -- f )
        mov     rcx,rax
        pop     rdi
        pop     rsi
        xor     rax,rax         ; default match
        repe    cmpsb
        je      .same
        jl      .less
        add     rax,2
.less:  dec     rax
.same:  next

code scan ; ( a n c -- a' n' )
        pop     rcx
        pop     rdi
        repne   scasb
;        jecxz   not_found
        dec     rdi
        push    rdi
        ; finish
        next

code code_end
