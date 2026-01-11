\ ITC-64 Forth Kernel

0 , \ cold start xt
0 , \ warm start xt (after exception)
0 , \ SP0
0 , \ RP0

%origin CONSTANT ORIGIN
DATA-ORIGIN CONSTANT DP0

%origin 0 cells + CONSTANT 'COLD
%origin 1 cells + CONSTANT 'WARM
%origin 2 cells + CONSTANT SP0
%origin 3 cells + CONSTANT RP0

\ ============================================================
\ Code words implemented in kernel.asm

CODE ;S         %unnest ,
CODE EXIT       %unnest ,
CODE BRANCH     %branch ,
CODE ?BRANCH    %branch_if_zero ,
CODE LIT        %lit32 ,
CODE (")        %litq ,

CODE +          %plus ,
CODE -          %minus ,
CODE *          %star ,
CODE /          %slash ,

CODE UM*        %um_star ,
CODE UM/MOD     %um_slash_mod ,
CODE /MOD       %slash_mod ,
CODE */MOD      %star_slash_mod ,

CODE AND        %andd ,
CODE OR         %orr ,
CODE XOR        %xorr ,

CODE @          %fetch ,
CODE !          %store ,
CODE +!         %plus_store ,
CODE C@         %cfetch ,
CODE C!         %cstore ,
CODE W@         %wfetch ,
CODE W!         %wstore ,
CODE DW@        %dwfetch ,
CODE DW!        %dwstore ,
CODE 2@         %two_fetch ,
CODE 2!         %two_store ,

CODE 0=         %zero_equal ,
CODE 0<         %zero_less ,
CODE 0>         %zero_greater ,
CODE =          %equal ,
CODE <          %less ,
CODE >          %greater ,
CODE U<         %uless ,
CODE U>         %ugreater ,
CODE WITHIN     %within ,
CODE NOT        %zero_equal ,

CODE DUP        %dupp ,
CODE DROP       %drop ,
CODE SWAP       %swap ,
CODE OVER       %over ,
CODE ROT        %rot ,
CODE NIP        %nip ,
CODE ?DUP       %qdup ,
CODE PICK       %pick ,

CODE >R         %to_r ,
CODE R>         %r_from ,
CODE R@         %r_at ,
CODE 2>R        %two_to_r ,
CODE 2R>        %two_r_from ,
CODE 2R@        %two_r_at ,

CODE SP@        %sp_fetch ,
CODE SP!        %sp_store ,
CODE RP@        %rp_fetch ,
CODE RP!        %rp_store ,

\  CODE I          %ii ,
\  CODE J          %jj ,
\  CODE LEAVE      %leave ,
\  CODE UNLOOP     %unloop ,

CODE 2DUP       %two_dup ,
CODE 2DROP      %two_drop ,
CODE 2SWAP      %two_swap ,               
CODE 2OVER      %two_over ,

CODE INVERT     %invert ,
CODE NEGATE     %negate ,
CODE LSHIFT     %lshift ,
CODE RSHIFT     %rshift ,

CODE 1+         %one_plus ,
CODE 1-         %one_minus ,
CODE 2*         %two_star ,
CODE 2/         %two_slash ,

CODE CELLS      %cells ,
CODE CELL+      %cell_plus ,

CODE COUNT      %count ,
CODE /STRING    %slash_string , ( a u n -- a+n u-n )

CODE FILL       %fill ,     ( a n c -- )
CODE CMOVE      %cmove ,    ( src dest n -- )
\  CODE CMOVE>     %cmoveup ,  ( src dest n -- )
CODE COMP       %comp ,     ( a1 a2 n -- -1/0/1 )

\ ============================================================
\ Target compiling words

t: ;        ?csp  [target] ;S  [target] [  t;
t: literal  ?exec  [target] LIT  dw,  t;
t: $        bl word number drop  [target] literal  t;

t: "        [target] (")  ,"  align4  t;

t: if       [target] ?BRANCH  >mark  t;
t: then     >resolve  t;
t: else     [target] BRANCH  >mark  2swap >resolve  t;
t: begin    <mark  t;
t: until    [target] ?BRANCH  <resolve  t;
t: again    [target] BRANCH   <resolve  t;
t: while    [target] if  2swap  t;
t: repeat   [target] again  [target] then  t;

\ ============================================================
\ Misc.

0 CONSTANT 0
1 CONSTANT 1

TRUE  CONSTANT TRUE
FALSE CONSTANT FALSE

CODE NOT   %zero_equal ,

: ON  ( a -- )  TRUE  SWAP ! ;
: OFF ( a -- )  FALSE SWAP ! ;

: */   */MOD NIP ;


\  : (.")      R> COUNT  2DUP + ALIGN4 >R  TYPE ;
\  t: "        [target] (.")  ,"  align4  t;

\  : CELL+  $ 8 + ;
\  : CELLS  $ 3 LSHIFT ;

: MOD  /MOD DROP ;

: PLACE ( a n dest -- )   2DUP C!  1+ SWAP CMOVE ;

\ ============================================================
\ System BIOS

CODE BIOS   %bios , ( ??? svc -- ??? )

: BYE   0 0 BIOS ;

CODE ARGC   %argc ,     ( -- n )
CODE ARGV   %argv ,     ( n -- a n )

\  CODE GETENV  ( name len -- value len )  top = get_env(S, top); NEXT
\  CODE SETENV  ( value len name len -- )  set_env(S, top); S += 3, pop; NEXT

\ Dynamic Libraries ********** )
\  CODE DLOPEN  ( name len -- handle )
\  CODE DLCLOSE ( handle -- )
\  CODE DLSYM ( name len handle -- sym )
\  CODE DLERROR ( -- addr len )
\  CODE DLCALL ( <args> #args sym -- result )

\ ============================================================
\ Terminal I/O

: KEY       ( -- char )     $ 01 BIOS ;
: EMIT      ( char -- )     $ 02 BIOS ;
: TYPE      ( a n --)       $ 03 BIOS ;
: ACCEPT    ( a n -- n )    $ 04 BIOS ;

$20 CONSTANT BL

: CR        $ A EMIT ;
: SPACE     BL EMIT ;

\ ============================================================
\ File I/O using libc

0 CONSTANT R/O  \ r
1 CONSTANT W/O  \ w
\ 2 is r+
3 CONSTANT R/W  \ w+

\   mode    create  open
\   r/o     r       r
\   w/o     w       r+ (best we can do)
\   r/w     w+      r+

: CREATE-FILE   ( c-addr u fam -- fid ior ) $ 10 BIOS ;
: OPEN-FILE     ( c-addr u fam -- fid ior ) DUP IF DROP $ 2 ( r+ ) THEN
                                            CREATE-FILE ;
: CLOSE-FILE    ( fid -- ior )              $ 11 BIOS ;
: READ-FILE     ( a u fid -- u' ior )       $ 12 BIOS ;
: READ-LINE     ( a u fid -- u' flag ior )  $ 13 BIOS ;
: WRITE-FILE    ( a u fid -- ior )          $ 14 BIOS ;
: WRITE-LINE    ( a u fid -- ior )          $ 15 BIOS ;

\ ============================================================
\ Memory allocation

: ALLOCATE   ( n -- a ior )      $ 20 BIOS ;
: RESIZE     ( a n -- a' ior )   $ 21 BIOS ;
: FREE       ( a -- ior )        $ 22 BIOS ;

\ Allocate counted and null-terminate string
: NEW-STRING ( adr len -- c-str )
    DUP 1+ 1+ ALLOCATE DROP >R
    DUP R@ C! ( count )
    0 OVER R@ 1+ + C! ( null term. )
    R@ 1+ SWAP CMOVE ( string ) R> ;

\ ============================================================
\ Input source processing

VARIABLE 'IN    ( current source, points to source struct below )

$100 CONSTANT #TIB  ( max input line )

: >IN       'IN @ ;                 \ offset into source
: 'SOURCE   'IN @ CELL+ ;           \ length & address of source
: FID       'IN @ $ 3 CELLS + ;     \ source file id
: LINE#     'IN @ $ 4 CELLS + ;     \ line # being interpreted
: TIB       'IN @ $ 5 CELLS + ;     \ text input buffer other than EVALUATE
: FNAME      TIB #TIB + ;           \ filename when including

#TIB 2* 5 CELLS + CONSTANT #SOURCE  ( size of each source entry )

\ todo: create in high memory
CREATE SOURCE-STACK    #SOURCE 8 * ALLOT  ( 8 entries )

: SOURCE        'SOURCE 2@ ;
: SOURCE-ID     FID @ ;

: SOURCE-DEPTH  >IN SOURCE-STACK -  #SOURCE / ;

: INIT-SOURCE   >IN OFF  TIB 0 'SOURCE 2!  0 0 FID 2! ;

: >SOURCE ( fname len fid | -1 -- )
\    SOURCE-DEPTH $ 7 U> ABORT" source nested too deeply"
    #SOURCE 'IN +!  INIT-SOURCE
    DUP FID !  0> IF  FNAME PLACE  THEN ;

: SOURCE> ( -- )
\    SOURCE-DEPTH 1 < ABORT" trying to pop empty source"
    SOURCE-ID 0> IF  SOURCE-ID CLOSE-FILE DROP  THEN
    #SOURCE NEGATE 'IN +! ;

: REFILL-TIB ( -- f )
    TIB #TIB ACCEPT  DUP 0< IF  DROP FALSE EXIT  THEN
    0 >IN 2!  TRUE ;

: REFILL-FILE ( -- f )
    TIB #TIB SOURCE-ID READ-LINE ( len flag ior )
    SWAP INVERT OR NOT ( not eof or error )
    ( len ) 0 >IN 2!  1 LINE# +! ;

: REFILL ( -- f )  \ push refill(SOURCE); NEXT
    SOURCE-ID 0< IF ( evaluate )  FALSE EXIT  THEN
    SOURCE-ID IF  REFILL-FILE  ELSE  REFILL-TIB  THEN ;


: QUERY  INIT-SOURCE  REFILL 0= IF BYE THEN ;

: QUIT  \ RESET  0 STATE !
    SOURCE-STACK 'IN !
    BEGIN  CR QUERY  AGAIN ;


\ ============================================================
\ test

here ," Hello from Forth!" constant greeting

: hello  greeting count type cr ;

: run   hello  QUIT  bye ;

t' run data-origin t!

\ ============================================================
0 [if]
\ ============================================================


\ ============================================================
\ ********** Numbers **********

` #define dot(n)  printf(BASE == 16 ? "%tx " : "%td ", n)

CODE .  ( n -- )  dot(top), pop; NEXT

CODE DIGIT ( ch -- n )  top = digit(top); NEXT

CODE -NUMBER  ( a -- a t, n f ) w = number(ptr(top), --S, BASE);
`   if (w) top = 0; else *S = top, top = -1; NEXT
: NUMBER  ( a -- n )  -NUMBER ABORT" ? " ;

CODE >NUMBER  top = to_number(S, top, BASE); NEXT

\ ============================================================
\ ********** Parsing **********

20 CONSTANT BL

CODE PARSE    ( c -- a n )  top = parse(SOURCE, top, --S); NEXT
CODE PARSE-NAME ( -- a n )  push parse_name(SOURCE, --S); NEXT

CODE WORD  ( char -- addr )
`   top = word(SOURCE, top, HERE); NEXT

\ ============================================================
\ ********** Dictionary search **********

CODE SEARCH-WORDLIST  ( c-addr u wid -- 0 | xt 1 | xt -1 )
    ` w = search_wordlist(S[1], S[0], top);
    ` if (w > 0) *++S = w, top = -1;
    ` else if (w < 0) *++S = -w, top = 1;
    ` else S += 2, top = 0; NEXT

CODE FIND  ( str -- xt flag | str 0 )
    ` w = find(top, ORIGIN + CELLS(CONTEXT));
    ` if (w > 0) *--S = w, top = -1;
    ` else if (w < 0) *--S = -w, top = 1;
    ` else push 0; NEXT

: '  ( --- xt )  BL WORD FIND 0= ABORT" ?" ;

CODE >NAME ( xt -- nfa )  top = xt_to_name(top); NEXT
CODE NAME> ( nfa -- xt )  top = name_to_xt(top); NEXT

CODE DEPTH ( -- n )  w = S0 - S; push w; NEXT
CODE .S ( -- )
    ` w = S0 - S; if (w <= 0) { printf("empty "); NEXT }
    ` S[-1] = top;
    ` for (w -= 2; w >= -1; w--) dot(S[w]);
    ` NEXT

CODE WORDS  ( -- )  words(M[CONTEXT]); NEXT
CODE DUMP  ( a n -- )  dump(*S++, top, BASE); pop; NEXT
CODE VERBOSE  push (cell)&verbose; NEXT

\ ============================================================
\ Catch/Throw ********** )

CODE EXECUTE ( xt -- )  *--R = (cell)I, I = (u8*)top, pop; NEXT

CODE CATCH  ( xt -- ex# | 0 )
    ` CATCH, *--R = (cell) &RESUME, I = (u8*)top, pop; NEXT

CODE THROW  ( n -- )
    ` if (!top) pop; else if (!HANDLER) goto abort; else THROW; NEXT

CODE RESET  R = R0, HANDLER = 0; NEXT
 
\ ============================================================
\ Compiler ********** )

VARIABLE dA ( offset for target compiler )
VARIABLE ?CODE 0 ,

: -OPT  0 ?CODE ! ;

CODE UNUSED  ( -- u )  push (cell)R0 - CELLS(256) - HERE; NEXT

: HERE   H @  ;
: ALLOT  H +! ;
: ,   HERE !  CELL H +! ;
: C,  HERE C!  1 H +! ;
: W,  HERE W!  $ 2 H +! ;
: H,  HERE  !  $ 4 H +! ;

CODE ALIGNED  top = aligned(top); NEXT
: ALIGN  BEGIN HERE CELL 1- AND WHILE 0 C, REPEAT ;

: OP, ( opc -- )  ?CODE @ HERE ?CODE 2!  C, ;

: LITERAL  $ 20 OP, , ; IMMEDIATE

: LATEST ( -- op | 0 )  ?CODE @ DUP IF C@ THEN ;
: PATCH  ( op -- )      ?CODE @ C! ;
: REMOVE ( -- )         0 ?CODE 2@  H !  ?CODE 2! ;

: LIT?  ( -- f )  ?CODE @ DUP IF  C@ $ 20 =  THEN ;
: LIT@  ( -- n )  ?CODE @ 1 + @ ;
: LIT!  ( n -- )  ?CODE @ 1 + ! ;

: BINARY ( op -- ) \ e.g. lit +
    LIT? IF  LIT@ REMOVE
        LIT? IF  LIT@ SWAP ROT ( n1 n2 op )
            HERE !  HERE EXECUTE  LIT!
        ELSE
            SWAP $ 40 XOR OP, ,
        THEN
    ELSE  OP,
    THEN ;

: MEMORY  ( op -- ) \ e.g lit @
    LIT? IF  $ 40 XOR PATCH  ELSE  OP,  THEN ;

: NOT,  ( op -- )  \ invert last conditional op
    LATEST  DUP $ 70 $ 80 WITHIN  OVER $ F7 AND $ 33 $ 38 WITHIN OR
    IF  $ 8 XOR PATCH DROP  ELSE  DROP OP,  THEN ;

: PACK ( opc -- ) \ peephole optimizer
    DUP $ 60 $ 80 WITHIN
    IF  DUP $ 68 $ 6B WITHIN IF  MEMORY EXIT  THEN
        DUP $ 70 =           IF  NOT,   EXIT  THEN
        BINARY EXIT
    THEN OP, ;

: LITOP ( xt -- )
    COUNT  SWAP @ [COMPILE] LITERAL  $ 40 XOR PACK ;

: INLINE?  ( xt -- n t | f ) \ count ops >= $60
    DUP BEGIN  DUP C@ WHILE
        COUNT $ 60 < IF  2DROP 0 EXIT  THEN
    REPEAT SWAP - $ -1 ;

: INLINE ( xt n -- ) 0 ?DO  COUNT PACK  LOOP DROP ;

: COMPILE,  ( xt -- )
    \ inline primatives
    DUP INLINE? IF INLINE EXIT THEN

    \ inline constant etc.
    DUP C@ $ 10 = IF ( constant ) CELL+ @      [COMPILE] LITERAL  EXIT THEN
    DUP C@ $ 11 = IF ( variable ) CELL+ dA @ - [COMPILE] LITERAL  EXIT THEN
    DUP C@ $ 13 = IF ( value )    CELL+ dA @ - $ 28 OP, ,         EXIT THEN

    \ inline lit op exit (e.g. 1+, HERE)
    DUP COUNT $ 20 $ 40 WITHIN  SWAP CELL+ C@ 0= AND IF  LITOP EXIT  THEN

\ Optional check for bad behavior!
\    DUP CELL 1- AND ABORT" xt not aligned"

    \ compile short call in first 64k cells
    DUP $ 10000 CELLS U< IF  $ 1 OP, dA @ - CELL / W,  EXIT THEN

    \ default to far call
    $ 2 OP, dA @ - , ;

( optimize tail calls )
: EXIT  LATEST $ 1 = IF  $ 9 PATCH  ELSE  0 OP,  THEN ; IMMEDIATE

\ ============================================================
\ Interpreter ********** )

: ?STACK  DEPTH 0< ABORT" stack?" ;

: INTERPRET  ( -- )
    BEGIN  BL WORD  DUP C@ WHILE
        FIND ?DUP IF
            STATE @ = IF  COMPILE,  ELSE  EXECUTE  ?STACK  THEN
        ELSE
            NUMBER  STATE @ IF  [COMPILE] LITERAL  THEN
        THEN
    REPEAT DROP ;

\ These are the foundations for REQUIRED, but I'm not
\ going to add the complexity right now. See also lib/path.f.
\ I thought this would eliminate the need to allocate the
\ file name for error reporting, but it won't do that since
\ after we add a path we might have a different name representing
\ the file we opened vs. the name given to INCLUDED/REQUIRED.
\ REQUIRED should just use the supplied name.
\ It may be better if we record the name after the files is included.
\ : LINK, ( a -- )  ALIGN HERE  OVER @ ,  SWAP ! ;
\ : S,  ( a n -- )  HERE SWAP  DUP ALLOT  MOVE ;
\ VARIABLE INCLUDES ( list of included files )
\ : INCLUDING ( name len -- )  INCLUDES LINK,  DUP C, S, ;

: (INCLUDE)  BEGIN REFILL WHILE INTERPRET REPEAT ;

: INCLUDE-FILE  ( str len fid -- )  >SOURCE  HANDLER @
    IF  ['] (INCLUDE) CATCH SOURCE> THROW  ELSE  (INCLUDE) SOURCE>  THEN ;

: INCLUDED  ( str len -- )
    2DUP R/O OPEN-FILE ABORT" file not found" INCLUDE-FILE ;

: INCLUDE  PARSE-NAME INCLUDED ;

: QUIT  RESET  0 STATE !
    BEGIN  SOURCE-DEPTH WHILE  SOURCE>  REPEAT
    BEGIN  CR QUERY  INTERPRET  STATE @ 0= IF ."  ok" THEN  AGAIN ;
1 HAS QUIT

TAG TAG

: COLD
    SOURCE-STACK 'IN !
    ARGC 1 ?DO  I ARGV INCLUDED  LOOP
    TAG COUNT TYPE  QUIT ;
0 HAS COLD

\ ============================================================
\ Defining Words ********** )

VARIABLE WARNING
: WARN  WARNING @ IF  >IN @  BL WORD FIND IF
    HERE COUNT TYPE ."  redefined " THEN  DROP >IN !  THEN ;

VARIABLE LAST 0,
: PRIOR ( -- nfa count )  LAST @ CELL+  DUP C@ ;
: p2  last @ 1- dup c@ ;

: HIDE      LAST @ @  CURRENT @ ! ;
: REVEAL    LAST @ ?DUP IF  CURRENT @ !  THEN ;
: LINK,     ALIGN HERE  OVER @ ,  SWAP ! ;
: S,        HERE SWAP  DUP ALLOT  MOVE ;

: (HEADER)  ( addr len wid -- )
            HERE ALIGNED LAST !  LINK,  DUP C,  S,  ALIGN
            HERE LAST CELL+ !  -OPT ;
: HEADER1    WARN  PARSE-NAME CURRENT @ (HEADER) ;

: NFA, ( a n -- ) \ name string from parse area or ?, not HERE!
    BEGIN  DUP 1+ HERE +  DUP ALIGNED - WHILE  0 C,  REPEAT ( align lfa )
    SWAP OVER S, C, ;
: LFA, ( wid -- )
    HERE  OVER @ $ 3 RSHIFT H,  SWAP !   $ -1 H,   ;
    
: (HEADER2)  ( addr len wid -- )  ROT ROT NFA,  LFA,  -OPT ;

VARIABLE WID2
: HEADER2   ( WARN ) PARSE-NAME  WID2 ( CURRENT @ )  (HEADER2) ;

: HEADER    >IN @  HEADER2  >IN !  HEADER1 ;
\  : HEADER    HEADER1 ;

: CONSTANT  HEADER  $ 10 , , ;
: CREATE    HEADER  $ 11 , ;
: VARIABLE  CREATE  0 , ;

\ | opc | I for does | data
: DOES>   R> dA @ -  $ 8 LSHIFT $ 12 OR  LAST CELL+ @ ! ;
: >BODY   CELL+ ;

\ Be careful from here on...

: [  0 STATE ! ; IMMEDIATE
T: ;  [COMPILE] EXIT [COMPILE] [ REVEAL ; IMMEDIATE forget
: RECURSE  LAST CELL+ @ COMPILE, ; IMMEDIATE

: ]  $ -1 STATE ! ;
: :NONAME  ALIGN HERE  DUP 0 LAST 2!  -OPT  ] ;
: :  HEADER HIDE ] ;

``
default:
    printf("Invalid opcode 0x%02X\n", I[-1]);
    top = -256;
    goto abort;
}
``
[then]
