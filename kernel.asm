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

; rcx,rdx,rsi,rdi,r8-r11 scratch (ebx too if not used)

; register aliases
%define sp rsp
%define rp ebp
%define ip r12
%define lp r13
%define up r14
%define dp r15

; Indirect threaded NEXT
; An XT is a 32-bit cell offset from r15 (32 GB max)
; ebx is the word register containing the current XT

%define next_1   mov     ebx,[ip]
%define next_2   add     ip,4
%define next_3   jmp     [dp+rbx*8]

%macro  next    0
        mov     ebx,[ip]               ; NEXT1
        add     ip,4                   ; NEXT2
        jmp     [dp+rbx*8]             ; NEXT3
%endmacro

        [map symbols code.map]

        bits    64
        org     1_0000_0000h            ; 4 GB origin for MacOS
origin:

; ==========================================================
; system variables in first 256 bytes (32 cells)
; ==========================================================

cold:           dq      cold_entry
warm:           dq      0
sp0:            dq      0
rp0:            dq      0
handler:        dq      0
                dq      (32-5) dup 0

; ==========================================================
; code starts at 0x1_0000_0100
; ==========================================================

cold_entry:
; ...


next0:  ; full 64-bit addresses
        mov     ebx,[ip]               ; NEXT1
        add     ip,8                   ; NEXT2
        jmp     [rbx]                ; NEXT3

next1:  ; 32-bit xt, no base
        mov     ebx,[ip]               ; NEXT1
        add     ip,4                   ; NEXT2
        jmp     [rbx*8]             ; NEXT3

next2: ; 32-bit offset from dp
        mov     ebx,[ip]               ; NEXT1
        add     ip,4                   ; NEXT2
        jmp     [dp+rbx*8]             ; NEXT3

; ==================== Runtime for Defining Words ====================

        align 16
docreate:
        push    rax
        lea     rax,[dp+rbx*8+8]
        next

        align 16
doconstant:
        push    rax
        mov     rax,[dp+rbx*8+8]
        next

        align 16
dodefer:
        mov     ebx,[dp+rbx*8+8]       ; pfa contains 32-bit XT
        jmp     [dp+rbx*8]             ; NEXT3

        align 16
docolon:
        mov     [rp-8],ip             ; save IP
        lea     ip,[dp+rbx*8+12]      ; new IP, NEXT2
        mov     ebx,[dp+rbx*8+8]       ; NEXT1
        sub     rp,8
        jmp     [dp+rbx*8]             ; NEXT3

        align 16
unnest:
        mov     ip,[rp]
        add     rp,8
        next

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

        align 16
does_template:
        push    rax                     ; push pfa
        lea     rax,[dp+rbx*8+8]

        mov     [rp-8],ip             ; save IP
        sub     rp,8

        mov     ip,qword does1               ; new IP from DOES> parent
        next

; This version reduces the generated code by factoring out the common part.

        align 16
does_template2:
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

        align 16
does_common:
        push    rax                     ; push pfa
        lea     rax,[dp+rbx*8+8]

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

        align 16
locals_start:
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

        align 16
locals_end:
        lea     rp,[lp+8]
        mov     lp,[lp]
        next

        align 16
local_fetch:    ; inline 4-byte local # (1,2,3, etc.)
        mov     ecx,[ip]       ; zero extend
        add     ip,4
        neg     rcx
        push    rax
        mov     rax,[lp+rcx*8]
        next

        align 16
local_store:    ; inline 4-byte local # (1,2,3, etc.)
        mov     ecx,[ip]       ; zero extend
        add     ip,4
        neg     rcx
        mov     [lp+rcx*8],rax
        pop     rax
        next

; ==================== Literals ====================

execute:
        mov     rbx,rax
        pop     rax
        jmp     [rbx*8]             ; NEXT3

lit32:  push    rax
        mov     eax,[ip]
        mov     ebx,[ip+4]
        add     ip,8
        cdqe                            ; sign extend eax->rax
        jmp     [rbx*8]             ; NEXT3

lit64:  push    rax
        mov     rax,[ip]
        mov     ebx,[ip+8]
        add     ip,12
        jmp     [rbx*8]             ; NEXT3

litq:
        xor     rcx,rcx
        push    rax
        mov     rax,ip                 ; counted-string address
        mov     cl,[ip]                ; rcx = length
        add     ip,rcx
        add     ip,4           ; count + padding
        and     ip,-4          ; 4-byte align
        next

; ==================== Branching ====================

        align 16
branch: mov     ecx,[ip]        ; 32-bit signed offset in bytes    
        movsxd  rcx,ecx
        add     ip,rcx
        next

        align 16
branch_if_zero:
        test    rax,rax
        pop     rax
        jz      branch
        add     ip,4
        next

; ==================== DO...LOOP ====================

; ==================== Stack ====================

        align 16
dupe:   push    rax
        next

        align 16
drop:   pop     rax
        next

        align 16
swap:   xchg    rax,[sp]
        next

        align 16
over:   mov     rcx,[sp]
        push    rax
        mov     rax,rcx
        next

        align 16
rot:    mov     rcx,[rsp]
        mov     rdx,[rsp+8]
        mov     [rsp],rax
        mov     [rsp+8],rcx
        mov     rax,rdx
        next

        align 16
nip:    pop     rcx
        next

        align 16
qdup:   test    rax,rax
        jnz     .nodup
        push    rax
.nodup  next

        align 16
pick:   mov     rax,[sp+rax*8]
        next

        align 16
to_r:   mov     [rp-8],rax
        sub     rp,8
        pop     rax
        next

        align 16
r_from: push    rax
        mov     rax,[rp]
        add     rp,8
        next

        align 16
r_at:   push    rax
        mov     rax,[rp]
        next

        align 16
rdrop:  add     rp,8    ; needed?
        next

        align 16
dup_to_r:
        mov     [rp-8],rax
        sub     rp,8
        next

        align 16
two_to_r:
        pop     rcx
        mov     [rp-16],rax
        pop     rax
        mov     [rp-8],rcx
        sub     rp,16
        next

        align 16
two_r_from:
        mov     rcx,[rp+8]
        push    rax
        mov     rax,[rp]
        push    rcx
        add     rp,16
        next

        align 16
two_r_at:
        mov     rcx,[rp+8]
        push    rax
        mov     rax,[rp]
        push    rcx
        next

        align 16
two_dup:
        mov     rcx,[sp]
        push    rax
        push    rcx
        next

        align 16
two_drop:
        pop     rax
        pop     rax
        next

        align 16
two_swap:
        mov     rbx,[sp]
        mov     rcx,[sp+8]
        mov     rdx,[sp+16]
        mov     [sp+16],rbx
        mov     [sp+8],rax
        mov     [sp],rdx
        mov     rax,rcx
        next

        align 16
two_over:
        mov     rcx,[sp+8]
        mov     rdx,[sp+16]
        push    rax
        push    rdx
        mov     rax,rcx
        next

; ==================== Arithmatic and Logic ====================

        align 16
plus:   pop     rcx
        add     rax,rcx
        next

        align 16
minus:  sub     rax,[sp]
        pop     rcx
        neg     rax
        next

        align 16
star:   pop     rcx
        mul     rcx
        next

        align 16
slash_mod:                      ; /MOD ( n1 n2 -- rem quot )
        mov     rcx,rax
        pop     rax
        xor     rdx,rdx
        div     rcx
        push    rdx
        next

        align 16
u_slash_mod:                    ; U/MOD ( n1 n2 -- rem quot )
        mov     rcx,rax
        pop     rax
        xor     rdx,rdx
        div     rcx
        push    rdx
        next

        align 16
star_slash_mod:                 ; */MOD ( n1 n2 n3 -- rem quot )  n1 * n2 / n3
        mov     rcx,rax ; n3
        pop     rbx     ; n2
        pop     rax     ; n1
        imul    rbx
        idiv    rcx
        push    rdx
        next

        align 16
invert: not     rax
        next

        align 16
negate: neg     rax
        next

        align 16
one_plus: inc rax
        next

; one_plus code 1+
; code 1+
;    inc rax
;    next
; end-code

        align 16
one_minus: dec rax
        next


; ==================== Memory ====================
; @ ! +! C@ C! W@ W! DW@ DW! 2@ 2!

        align 16
fetch:  mov     rax,[rax]
        next

        align 16
store:  pop     rcx
        mov     [rax],rcx
        pop     rax
        next

        align 16
two_fetch:
        mov     rcx,[rax+8]
        mov     rax,[rax]
        push    rcx
        next

        align 16
two_store:
        pop     rcx
        pop     rdx
        mov     [rax],rcx
        mov     [rax+8],rdx
        pop     rax
        next

        align 16
plus_store:
        pop     rcx
        add     [rax],rcx
        pop     rax
        next

        align 16
cfetch: xor     rcx,rcx
        mov     cl,[rax]
        mov     rax,rcx
        next

        align 16
cstore: pop     rcx
        mov     [rax],cl
        pop     rax
        next

        align 16
wfetch: xor     rcx,rcx
        mov     cx,[rax]
        mov     rax,rcx
        next

        align 16
wstore: pop     rcx
        mov     [rax],cx
        pop     rax
        next

        align 16
dwfetch: mov     eax,[rax]
        next

        align 16
dwstore: pop     rcx
        mov     [rax],ecx
        pop     rax
        next

        align 16
        next

        align 16
        next

        align 16
        next

        align 16
        next

        align 16
        next

; ==================== Comparison ====================
; 0= 0< 0> = < > U< U>

        align 16
zero_equal:
        test    rax,rax
        mov     rax,0
        jnz     .1
        dec     rax
.1:     next

        align 16
zero_less:
        test    rax,rax
        mov     rax,0
        jns     .1
        dec     rax
.1:     next

        align 16
zero_greater:
        test    rax,rax
        mov     rax,0
        jle     .1
        dec     rax
.1:     next

        align 16
equal:  pop     rcx
        cmp     rcx,rax
        mov     rax,0
        jne     .1
        dec     rax
.1:     next

        align 16
less:   pop     rcx
        cmp     rcx,rax
        mov     rax,0
        jge     .1
        dec     rax
.1:      next

        align 16
greater:pop     rcx
        cmp     rcx,rax
        mov     rax,0
        jle     .1
        dec     rax
.1:     next

        align 16
uless:  pop     rcx
        cmp     rcx,rax
        mov     rax,0
        jae     .1
        dec     rax
.1:     next

        align 16
ugreater:  pop     rcx
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

cmove:
        mov     rcx,rax
        pop     rdi
        pop     rsi
        pop     rax
        rep     movsb
        next                    ; interleave

fill:   ; ( addr len char -- )
        pop     rcx
        pop     rdi
        rep     stosb
        pop     rax
        next

comp:   ; ( a1 a2 n -- f )
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

scan:   ; ( a n c -- a' n' )
        pop     rcx
        pop     rdi
        repne   scasb
;        jecxz   not_found
        dec     rdi
        push    rdi
        ; finish
        next


; Keep linker happy
;section .note.GNU-stack noalloc noexec nowrite progbits
