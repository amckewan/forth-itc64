; x86 Forth registers
;
; rax = top of stack
; rbx = word pointer (xt)
; rsp = data stack pointer
; rbp = return stack pointer
; r12 = instruction pointer (rsi candidate for shorter-form asm)
; r13 = locals pointer
; r14 = user pointer
; r15 = dictionary origin

; register aliases
; rsp
%define rrp ebp
%define rip r12
%define rlp r13
%define rup r14
%define rdp r15

; rcx,rdx,rsi,rdi,r8-r11 scratch (ebx too if not needed)

        [map symbols forth.map]

        bits    64
        org     0x100000000             ; 4 GB for MacOS
origin:

; ==========================================================
; system variables in first 256 bytes (32 cells)
; ==========================================================

cold:   dq      cold_entry
warm:   dq      0
sp0:    dq      0
rp0:    dq      0
        dq      30 dup 0

; ==========================================================
; code starts at 0x100000100
; ==========================================================

cold_entry:
        mov     r15,origin
        mov     rsp,[sp0]
        mov     rbp,[rp0]
; ...

; indirect threaded NEXT
; An XT is a cell offset from r15 (32 GB max)
; ebx is the word register containing the current XT
%macro  next    0
        mov     ebx,[r12]               ; NEXT1
        add     r12,4                   ; NEXT2
        jmp     [r15+rbx*8]             ; NEXT3
%endmacro

next0:  ; full 64-bit addresses
        mov     rbx,[rip]               ; NEXT1
        add     r12,8                   ; NEXT2
        jmp     [rbx]                ; NEXT3

next1:  ; 32-bit xt, no base
        mov     ebx,[r12]               ; NEXT1
        add     r12,4                   ; NEXT2
        jmp     [rbx*8]             ; NEXT3

next2: ; 32-bit offset from r15
        mov     ebx,[r12]               ; NEXT1
        add     r12,4                   ; NEXT2
        jmp     [r15+rbx*8]             ; NEXT3

        align 16
docreate:
        push    rax
        lea     rax,[r15+rbx*8+8]
        next

        align 16
doconstant:
        push    rax
        mov     rax,[r15+rbx*8+8]
        next

        align 16
dodefer:
        mov     ebx,[r15+rbx*8+8]       ; pfa contains 32-bit XT
        jmp     [r15+rbx*8]             ; NEXT3

        align 16
docolon:
        mov     [rbp-8],r12             ; save IP
        lea     r12,[r15+rbx*8+12]      ; new IP, NEXT2
        mov     ebx,[r15+rbx*8+8]       ; NEXT1
        sub     rbp,8
        jmp     [r15+rbx*8]             ; NEXT3

        align 16
unnest:
        mov     r12,[rbp]
        add     rbp,8
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
        lea     rax,[r15+rbx*8+8]

        mov     [rbp-8],r12             ; save IP
        sub     rbp,8

        mov     r12,qword does1               ; new IP from DOES> parent
        next

; This version reduces the generated code by factoring out the common part.

        align 16
does_template2:
        mov     rdx,qword does_common   ; common DOES> routine
        mov     rcx,qword does1         ; unique IP from DOES> parent
        jmp     rdx

;   133 00000210 48BA-                           mov     rdx,qword does_common   ; common DOES> routine
;   133 00000212 [3002000000000000] 
;   134 0000021A 49BC-                           mov     r12,qword does1         ; unique IP from DOES> parent
;   134 0000021C [5502000000000000] 
;   135 00000224 FFE2                            jmp     rdx
;
; : {code}  CP @ DP @ CP ! DP ! ; \ swap CP and DP
; : align16  begin  here 15 and while  $90 c,  repeat ;
; : DOES,  {code}  align16  $BA48 w, $100002030 ,  $BC49 w, here ,  $E2FF w,  {code} ;

        align 16
does_common:
        push    rax                     ; push pfa
        lea     rax,[r15+rbx*8+8]

        mov     [rbp-8],r12             ; save IP
        sub     rbp,8

        mov     r12,rcx                 ; new IP from DOES> parent
        next

dodoes_parent:
        dd      0               ; ;code
        dd      0               
does1:
        dd      $12345678       ; 1st xt of does> part

;;;;;;;;;;;;; Locals ;;;;;;;;;;;;;;;;;;;

local_start:    ; inline #locals,#params,0,0
        mov     [rbp-8],r14             ; save LP to R-stack
        lea     r14,[rbp-8]             ; new LP -> old LP
        lea     rbp,[rbp-8]

        xor     ecx,ecx
        mov     cl,[r13]                ; locals count
        inc     r13
        jecxz   nolocs
        xor     rdx,rdx
locs:   mov     [rbp-8],rdx
        sub     rbp,8
        loop    locs
nolocs:

        mov     cl,[r13]                ; params count
        add     r13,3
        jecxz   noparams
params: mov     [rbp-8],rax
        sub     rbp,8
        pop     rax
        loop    params
noparams:
        next

locals_end:
        lea     rbp,[r14+8]
        mov     r14,[r14]
        next

local_fetch:    ; inline 4-byte local # (1,2,3, etc.)
        mov     ecx,[r13]       ; zero extend
        add     r13,4
        neg     rcx
        push    rax
        mov     rax,[r14+rcx*8]
        next

local_store:    ; inline 4-byte local # (1,2,3, etc.)
        mov     ecx,[r13]       ; zero extend
        add     r13,4
        neg     rcx
        mov     [r14+rcx*8],rax
        pop     rax
        next

;;;;;;;;;;;;;;;;;;; Literals ;;;;;;;;;;;;;;;;;


plus:   pop     rcx
        add     rax,rcx
        next

dupe:   push    rax
        next

execute:
        mov     rbx,rax
        pop     rax
        jmp     [rbx*8]             ; NEXT3

lit32:  push    rax
        mov     eax,[r13]
        mov     ebx,[r13+4]
        add     r13,8
        cdqe                            ; sign extend eax->rax
        jmp     [rbx*8]             ; NEXT3

lit64:  push    rax
        mov     rax,[r13]
        mov     ebx,[r13+8]
        add     r13,12
        jmp     [rbx*8]             ; NEXT3

litq:
        xor     rcx,rcx
        push    rax
        mov     rax,r13                 ; counted-string address
        mov     cl,[r13]                ; rcx = length
        add     r13,rcx
        add     r13,4           ; count + padding
        and     r13,-4          ; 4-byte align
        next

;;;;;;;;;;; Branching ;;;;;;;;;;;;;;;;

branch:
        mov     ecx,[r13]       ; 32-bit signed offset in bytes
        movsxd  rcx,ecx
        add     r13,rcx
        next

branch2:
        mov     ecx,[r13]       ; 32-bit signed offset in bytes
        movsxd  rcx,ecx
        mov     ebx,[r13+rcx]           ; NEXT1
        lea     r13,[r13+rcx+4]         ; NEXT2
        jmp     [rbx*8]             ; NEXT3

branch_if_zero:
        test    rax,rax
        pop     rax
        jz      branch
no_branch:
        add     r13,4
        next
no_branch2:
        mov     ebx,[r13+4]             ; NEXT1
        add     r13,8                   ; NEXT2
        jmp     [rbx*8]             ; NEXT3

;;;;;;;;;;;;;; Block Memory ;;;;;;;;;;;;;;;;;;;

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
        je      same
        jl      less
more:   add     rax,2
less:   dec     rax
same:   next

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
