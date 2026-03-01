; x86 Forth registers
;
; rax = top of stack
; rbx = word pointer (xt)
; rcx = free
; rdx = free
; rsi = free
; rdi = free
; rsp = data stack pointer
; rbp = return stack pointer
; r8-r11 = free
; r12 = instruction pointer
; r13 = locals pointer
; r14 = user pointer
; r15 = dictionary origin

; Forth register aliases
%define sp rsp
%define rp rbp
%define ip r12
%define lp r13
%define up r14

; Indirect threaded NEXT
; An XT is a 32-bit cell offset from r15 (32 GB max)
; rbx is the word register containing the current XT

; These are valid for the currently executing word:
%define cfa     r15+rbx*8
%define pfa     cfa+8

%define XT(addr)   (((addr) - origin) >> 3)

%macro  next    0
        mov     ebx,[ip]        ; fetch xt (ebx zero extended -> rbx)
        add     ip,4            ; advance ip
        jmp     [cfa]           ; indirect jump via code field
%endmacro

; We could optimize the code by interleaving parts of next
; to improve pipeline utilization.
; This is done in a few places but otherwise I took a straightforward approach.
;%define next_1a   mov     ebx,[ip]
;%define next_1b   add     ip,4
;%define next_2    jmp     [cfa]

; code is 16-byte aligned (x86 code read size)
%macro  code    1
        align   16
   %1:
%endmacro

; ==========================================================
; Start of code space, 4 GB origin

        [map symbols code.map]  ; map file for symbols
        bits    64
        org     1_0000_0000h    ; 4 GB
origin:                         ; <--- r15

; ==========================================================
; Variables

%define sysvar(var)     [r15+var-origin]

; system variables shared with the C wrapper at known offsets
                dq      cold    ; 0 = cold start entry
                dq      warm    ; 8 = exception entry

; Module variables only referenced in this file.
; These are initialized in cold, then read only.
; We provide code words to read or use them.
m_bios:         dq      0       ; i64* bios(i64 svc, i64* sp)
m_limit:        dq      0       ; end of dictionary
m_argc:         dq      0       ; filtered, some options consumed by wrapper
m_argv:         dq      0       ; null-terminated strings (todo: fix this!)

; ==========================================================
; Variables shared with Forth.
; These start at DATA_START (origin + 8K).
; We can reference them as offsets from r15 (origin).

%define CODE_SIZE       2000h

%define COLD_XT         (CODE_SIZE + 0)
%define WARM_XT         (CODE_SIZE + 8)

; This is the extent of what we know about the structure of
; the Forth dictionary.

; ==========================================================
; Cold start entry from C wrapper.
; Linus/MacOS ABI: 6 args passed in RDI, RSI, RDX, RCX, R8, and R9
; (tbd) Windows ABI: 4 args passed in RCX, RDX, R8, and R9
;
; int cold(int argc, char *argv[], u64 memsize, bios_t bios);
;              rdi         rsi         rdx             rcx

code cold
        push    rbp             ; save registers
        push    rbx
        push    r12
        push    r13
        push    r14
        push    r15

; init forth registers
        mov     r15,origin      ; r15 = origin
        mov     rbp,rsp         ; rbp = rp = C's stack
        lea     rsp,[r15+rdx]   ; rsp = sp = top of memory (limit)
        lea     ip,[r15+(forth_return_ip - origin)]  ; ip = return from cold

; save args
        mov     sysvar(m_argc),rdi
        mov     sysvar(m_argv),rsi
        mov     sysvar(m_limit),rsp     ; limit not memsize
        mov     sysvar(m_bios),rcx

; 'COLD @ EXECUTE
        mov     ebx,[r15+COLD_XT]       ; rbx = xt
        jmp     [cfa]

; If the Forth cold entry exits, we'll get here.
; The return value from cold() is the top of the stack.
code forth_return
        mov     rsp,rbp         ; restore ABI registers
        pop     r15
        pop     r14
        pop     r13
        pop     r12
        pop     rbx
        pop     rbp
        ret

; headless code word
        align 8
forth_return_cfa:
        dq      forth_return

; ip that will execute the return
        align 4
forth_return_ip:
        dd      XT(forth_return_cfa)

; ==========================================================
; Warm start after signal

code warm ; sig code passed in rdi
        push    rbp             ; save registers
        push    rbx
        push    r12
        push    r13
        push    r14
        push    r15

; init forth registers
        mov     r15,origin      ; r15 = origin
        mov     rbp,rsp         ; rbp = rp = C's stack
        mov     rsp, sysvar(m_limit)    ; sp = saved limit
        lea     ip,[r15+(forth_return_ip - origin)]

; 'WARM @ EXECUTE
        mov     rax,rdi                 ; top = signal #
        push    rax                     ; avoid sigsegv on drop
        mov     ebx,[r15+WARM_XT]       ; rbx = xt
        jmp     [cfa]

; ==========================================================
; get args passed in from C

code argc       ; ( -- n )
        push    rax
        mov     rax,sysvar(m_argc)
        next

code argv       ; ( n -- a n )
        mov     rsi,sysvar(m_argv)
        mov     rdi,[rsi+rax*8]         ; argv[n]
        mov     rax,rdi
        xor     rcx,rcx
.1:     cmp     cl,[rax]
        je      .2
        inc     rax
        jmp     .1
.2:     sub     rax,rdi
        push    rdi
        next

code limit      ; ( -- addr )
        push    rax
        mov     rax,sysvar(m_limit)
        next

; ==========================================================
; Call into C BIOS:  i64 *bios(i64 svc, i64 *sp)
; The bios() function takes a service code and a pointer to the stack.
; Services take arguments and return results on the stack.
; bios() returns a (possibly) updated stack pointer.
; ABI args: rdi,rsi,rdx,rcx,r8,r9   saves: rbp,rbx,r12-15

code bios       ; BIOS ( ??? svc -- ??? )
        mov     rdi,rax         ; svc
        mov     rsi,sp          ; sp

        mov     rbx,rp          ; save rp
        mov     rsp,rbp         ; call on C's stack
        and     rsp,-16         ; align to 16 bytes, recommended, harmless

        mov     rax,sysvar(m_bios)
        call    rax

        mov     sp,rax          ; set sp from bios return
        mov     rp,rbx          ; restore rp
        pop     rax
        next

; ==========================================================
; Runtime for Defining Words

code doconstant
        push    rax
        mov     rax,[pfa]
        next

code dovariable
        push    rax
        lea     rax,[pfa]
        next

code dodefer
        mov     rbx,[pfa]       ; pfa contains XT
        jmp     [cfa]

code docolon
        mov     [rp-8],ip       ; save ip
        lea     ip,[pfa+4]      ; new ip + 4
        mov     ebx,[pfa]       ; 1st xt in colon def.
        sub     rp,8
        jmp     [cfa]           ; execute

code unnest
        mov     ip,[rp]
        add     rp,8
        next

code execute
        mov     rbx,rax
        pop     rax
        jmp     [cfa]

; ==========================================================
; CREATE/DOES>
; Portable, uses an extra cell per child word like FIG-Forth.
;
; Child cfa   -> docreate
;       pfa   -> ip of parent DOES> part, or 0 of no DOES> part
;       pfa+8 -> child body
;
; Example code generated by : ARRAY ( n -- )  CREATE ALLOT  DOES> +  ;
;        dd      CREATE
;        dd      ALLOT
;        dd      ;DOES          ; patches latest word (child) and exits
;does_child:                    ; child pfa points here
;        dd      +              ; first word of DOES> part
;        dd      ;S

code docreate
        mov     rcx,[pfa]       ; get DOES> IP
        jrcxz   nodoes          ; 0 for plain CREATE words
        mov     [rp-8],ip       ; save IP
        sub     rp,8
        mov     ip,rcx          ; set new IP to DOES> part
nodoes: push    rax             ; push body address
        lea     rax,[pfa+8]
        next

code to_body                    ; >BODY ( xt -- addr )
        lea     rax,[r15 + rax*8 + 2*8] ; cfa 2 cells +
        next

; ==================== Local Variables ====================
; Untested, not sure why I bothered, so complicated!
; At least they should just be variables and return their addresses,
; that way we don't need a complicated TO. So un-Forth-like.
; local{ ( -- )  build local stack frame
; followed inline by 4 bytes: #locals,#params,0,0

; simple idea:
; local{ A B C D } - defines named local variables, uninitialized
; : min  local{ a b }  b ! a !   a @ b @ < if a else b then @ ;
; now we get @ ! +! on off ... easy to pass around ...

code locals_start
        mov     [rp-8],lp       ; save LP to R-stack
        lea     lp,[rp-8]       ; new LP -> old LP
        lea     rp,[rp-8]

        mov     ecx,[ip]        ; rcx = locals size in bytes
        add     ip,4
        sub     rp,rcx          ; allocate space for locals
        next



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

code local_addr    ; inline 4-byte local # (1,2,3, etc.)
        mov     ecx,[ip]       ; zero extend
        add     ip,4
        neg     rcx
        push    rax
        mov     rax,[lp + rcx*8]  ; index -8,-16, etc.
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

code lit64      ; LIT ( -- n )
        push    rax
        mov     rax,[ip]
        add     ip,8
        next

code lit32      ; LIT32 ( -- n ) \ sign extended
        push    rax
        mov     eax,[ip]
        add     ip,4
        cdqe                    ; sign extend eax->rax
        next

code litq       ; (")  ( -- addr len ) \ 0-255
        push    rax
        xor     rax,rax
        mov     al,[ip]         ; rax = len
        lea     rcx,[ip+1]      ; rcx = address
        lea     ip,[ip+1+rax+3] ; count + chars + padding
        and     ip,-4           ; 4-byte align
        push    rcx
        next

;code lit_to ; ( n -- ) runtime for TO, xt follows
;        mov     ebx,[ip]        ; rbx = xt of VALUE or DEFER
;        add     ip,4            ; todo opt.
;        mov     [pfa],rax
;        pop     rax
;        next

; ==================== Branching ====================

code branch
        mov     ecx,[ip]        ; 32-bit signed offset in bytes    
        movsxd  rcx,ecx
        add     ip,rcx
        next

branch2:
        mov     ecx,[ip]        ; 32-bit signed offset in bytes    
        movsxd  rcx,ecx
        mov     ebx,[ip+rcx]    ; next xt
        lea     ip,[ip+rcx+4]   ; advance ip 
        jmp     [cfa]           ; indirect jump via code field


code branch_if_zero
        test    rax,rax
        pop     rax
        jz      branch
        add     ip,4
        next

;code of         ; over = if drop
;        pop     rcx
;        cmp     rcx,rax
;        je      .1
;.1:     add     ip,4            ; enter OF..ENDOF
;        pop     rax             ; DROP 
;        next

; ==================== DO...LOOP ====================
; From F83. Complicated setup makes LOOP faster. Unnecessary here :)

code do                         ; (DO)  ( limit index -- )
        pop     rdx             ; limit
doit:   sub     rp,3*8

        mov     ecx,[ip]        ; 32-bit signed offset in bytes to end of loop   
        movsxd  rcx,ecx
        add     rcx,ip
        add     ip,4            ; skip offset
        mov     [rp+2*8],rcx    ; save address (ip after loop) for LEAVE

        mov     rcx,8000_0000_0000_0000h
        add     rdx,rcx
        mov     [rp+1*8],rdx

        sub     rax,rdx
        mov     [rp],rax

        pop     rax
        next
        
code qdo                        ; (?DO)  ( limit index -- )
        pop     rdx
        cmp     rdx,rax
        jne     doit
        pop     rax
        jmp     branch

code    loopp                   ; (LOOP)  ( -- )
        mov     rcx,1
doloop: add     [rp],rcx
        jno     branch
        add     ip,4
        add     rp,3*8
        next

code    ploop                   ; (+LOOP)  ( n -- )
        mov     rcx,rax
        pop     rax
        jmp     doloop

code    unloop                  ; UNLOOP  ( -- )
        add     rp,3*8
        next

code    leave                   ; LEAVE  ( -- )
        mov     ip,[rp+2*8]
        add     rp,3*8
        next

code    i                       ; I  ( -- n )
        push    rax
        mov     rax,[rp]
        add     rax,[rp + 8]
        next

code    j                       ; J  ( -- n )
        push    rax
        mov     rax,[rp + 3*8]
        add     rax,[rp + 4*8]
        next

; ==================== Stack ====================

code dupp
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

code tuck ; ( n1 n2 -- n2 n1 n2 )
        pop     rcx
        push    rax
        push    rcx
        next

code qdup
        test    rax,rax
        jz      .nodup
        push    rax
.nodup  next

code pick
        mov     rax,[sp+rax*8]
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

code sp_fetch
        push    rax
        mov     rax,sp
        next

code sp_store
        mov     sp,rax
        pop     rax
        next

code rp_fetch
        push    rax
        mov     rax,rp
        next

code rp_store
        mov     rp,rax
        pop     rax
        next

; ==================== Arithmetic ====================

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
        cqo
        idiv    rcx
        next

code slash_mod                  ; /MOD ( n1 n2 -- rem quot ) over 0< swap sm/rem ;
        mov     rcx,rax
        pop     rax
        cqo
        idiv    rcx
        push    rdx
        next

code u_slash_mod                ; U/MOD ( u1 u2 -- rem quot )
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

; Doubles of questionable use

code m_star                    ; M* ( n1 n2 -- d )
        pop     rcx
        imul    rcx
        push    rax
        mov     rax,rdx
        next

code um_star                    ; UM* ( u1 u2 -- ud )
        pop     rcx
        mul     rcx
        push    rax
        mov     rax,rdx
        next

code m_slash_mod                ; M/MOD or SM/REM ( d n -- rem quot )
        mov     rcx,rax
        pop     rdx
        pop     rax
        idiv    rcx
        push    rdx
        next

code um_slash_mod               ; UM/MOD ( ud u -- rem quot )
        mov     rcx,rax
        pop     rdx
        pop     rax
        div     rcx
        push    rdx
        next

; Unary ops

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

code fetch
        mov     rax,[rax]
        next

code store
        pop     rcx
        mov     [rax],rcx
        pop     rax
        next

code plus_store
        pop     rcx
        add     [rax],rcx
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

code within     ; ( u low high -- f )
        pop     rcx
        pop     rdx
        sub     rax,rcx         ; high - low
        sub     rdx,rcx         ; u - low
        cmp     rdx,rax
        mov     rax,0
        jae     .1
        dec     rax
.1      next

; ==================== Number Conversion ====================

; Convert character to digit in base, return true if valid.
; Maps a-z to A-Z.
code digit ; ( char base -- n f )
        pop     rdx             ; dl = char
        mov     rbx,rax         ; bl = base
        xor     rax,rax         ; default fail
        mov     dl,[r15 + (toupper_table - origin) + rdx]
        sub     dl,'0'
        cmp     dl,9
        jbe     .base           ; '0' to '9'
        sub     dl,'A' - ('9' + 1)
        cmp     dl,9
        jbe     .done           ; between '9' and 'A'
.base:  cmp     dl,bl
        jae     .done           ; too big for base
        dec     rax             ; ok
.done   push    rdx
        next

; Standard >NUMBER, unnecessary with 64-bit cells.
code tonum      ; >NUM ( ud a n base -- ud' a' n' )
        mov     rdi,rax         ; rdi = base
        pop     rcx             ; rcx = len
        pop     rsi             ; rsi = addr
        pop     r8              ; r8:r9 = ud
        pop     r9
        jrcxz   .done

        xor     rbx,rbx
.loop:  mov     bl,[rsi]         ; get next digit in rbx
        cmp     bl,'9'
        jbe     .1

        or      bl,20h          ; force lower case
        sub     bl,'a'
        jb      .done
        add     bl,10
        jmp     .2

.1:     sub     bl,'0'
        jb      .done

.2:     cmp     rbx,rdi         ; digit < base?
        jnb     .done

        mov     rax,r9          ; multiply r8:r9 by base
        mul     rdi
        mov     r9,rax
        mov     r10,rdx
        mov     rax,r8
        mul     rdi
        mov     r8,rax
        add     r8,r10

        add     r9,rbx          ; add next digit
        adc     r8,0

        inc     rsi             ; repeat until done
        loop    .loop

.done:  push    r9
        push    r8
        push    rsi
        mov     rax,rcx
        next

; ==================== Strings ====================

code count
        lea     rcx,[rax+1]
        movzx   rax,byte [rax]
        push    rcx
        next

code slash_string       ; ( a u n -- a+n u-n )
        mov     rcx,rax
        pop     rax
        pop     rdx
        add     rdx,rcx
        sub     rax,rcx
        push    rdx
        next

; ==================== Block Memory ====================

code cmove
        mov     rcx,rax
        pop     rdi
        pop     rsi
        pop     rax
        cld
        rep     movsb
        next

code cmoveup
        mov     rcx,rax
        pop     rdi
        pop     rsi
        pop     rax
moveup: lea     rsi,[rsi+rcx-1]
        lea     rdi,[rdi+rcx-1]
        std
        rep     movsb
        cld
        next

code move
        mov     rcx,rax
        pop     rdi
        pop     rsi
        pop     rax
        cmp     rsi,rdi
        jb      moveup
        cld
        rep     movsb
        next

code fill   ; ( addr len char -- )
        pop     rcx
        pop     rdi
        cld
        rep     stosb
        pop     rax
        next

code skip ; SKIP ( a n char -- a' n' )
        pop     rcx
        jrcxz   .done
        pop     rdi
        cld
        repe    scasb
        je      .end
        dec     rdi     ; back up to 1st non-matching char
        inc     rcx
.end:   push    rdi
.done:  mov     rax,rcx
        next

code scan ; SCAN ( a n char -- a' n' )
        pop     rcx
        jrcxz   .done
        pop     rdi
        cld
        repne    scasb
        jne     .end
        dec     rdi     ; back up to 1st matching char
        inc     rcx
.end:   push    rdi
.done:  mov     rax,rcx
        next

code comp ; ( a1 a2 n -- -1/0/1 )
        mov     rcx,rax
        pop     rdi
        pop     rsi
        xor     rax,rax         ; default match
        cld
        repe    cmpsb
        je      .same
        jl      .less
        add     rax,2
.less:  dec     rax
.same:  next

; Case-insensitive compare for dictionary search, 0 if equal
code icomp ; ( a1 a2 n -- f )
        mov     rcx,rax
        pop     rdi
        pop     rsi
        xor     rax,rax         ; default match
        xor     rbx,rbx         ; used as index to upper table
        cld
.comp:  repe    cmpsb
        je      .same
        mov     bl,[rsi-1]      ; check ignoring case
        mov     dl,[r15 + (toupper_table - origin) + rbx]
        mov     bl,[rdi-1]
        cmp     dl,[r15 + (toupper_table - origin) + rbx]
        je      .comp
        dec     rax             ; no match
.same:  next

toupper_table:          ; Lookup table for uppercase conversion
        %assign i 0
        %rep 256
            %if i >= 'a' && i <= 'z'
                db i - ('a' - 'A')  ; Convert lowercase to uppercase
            %else
                db i                ; Keep all other characters unchanged
            %endif
            %assign i i+1
        %endrep

; COMPARE ( c-addr1 u1 c-addr2 u2 -- n )
; Compare the string specified by c-addr1 u1 to the string specified
; by c-addr2 u2. The strings are compared, beginning at the given addresses,
; character by character, up to the length of the shorter string or until
; a difference is found. If the two strings are identical, n is zero.
; If the two strings are identical up to the length of the shorter string,
; n is minus-one (-1) if u1 is less than u2 and one (1) otherwise.
; If the two strings are not identical up to the length of the shorter string,
; n is minus-one (-1) if the first non-matching character in the string
; specified by c-addr1 u1 has a lesser numeric value than the corresponding
; character in the string specified by c-addr2 u2 and one (1) otherwise.

code compare    ; COMPARE ( c-addr1 u1 c-addr2 u2 -- n )
        mov     rcx,rax         ; rax = u2
        pop     rdi
        pop     rdx             ; rdx = u1
        pop     rsi
        cmp     rax,rdx
        jbe     .1
        mov     rcx,rdx         ; u1 < u2
.1:     cld
        repe    cmpsb
        jb      .less
        ja      .more

        cmp     rdx,rax
        jb      .less
        ja      .more

        xor     rax,rax         ; strings equal
        next

.less:  mov     rax,-1
        next

.more:  mov     rax,1
        next

code    code_end
