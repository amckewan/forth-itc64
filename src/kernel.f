\ ITC-64 Forth Kernel

HERE 0 , \ cold start xt
HERE 0 , \ warm start xt (after exception, # in tos)

%origin CONSTANT ORIGIN

CONSTANT 'WARM
CONSTANT 'COLD

\ todo: user variables
VARIABLE SP0
VARIABLE RP0

\ ============================================================
\ Code words implemented in kernel.asm
\ Generally following F83 implementation

CODE ;S         %unnest ,
CODE EXIT       %unnest ,
CODE EXECUTE    %execute ,

CODE BRANCH     %branch ,
CODE ?BRANCH    %branch_if_zero ,
CODE (DO)       %do ,
CODE (?DO)      %qdo ,
CODE (LOOP)     %loopp ,
CODE (+LOOP)    %ploop ,
CODE UNLOOP     %unloop ,
CODE LEAVE      %leave ,
CODE I          %i ,
CODE J          %j ,

CODE LIT        %lit64 ,
CODE LIT32      %lit32 , \ sign-extended
CODE (")        %litq , \ ( -- addr len )

CODE +          %plus ,
CODE -          %minus ,
CODE *          %star ,
CODE /          %slash ,

CODE /MOD       %slash_mod ,
CODE */MOD      %star_slash_mod ,
CODE U/MOD      %u_slash_mod ,

CODE UM*        %um_star ,
CODE UM/MOD     %um_slash_mod ,
CODE M*         %m_star ,
CODE SM/REM     %m_slash_mod ,

CODE AND        %andd ,
CODE OR         %orr ,
CODE XOR        %xorr ,
CODE LSHIFT     %lshift ,
CODE RSHIFT     %rshift ,

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
CODE TUCK       %tuck ,
CODE ?DUP       %qdup ,
CODE PICK       %pick ,

CODE 2DUP       %two_dup  ,
CODE 2DROP      %two_drop  ,
CODE 2SWAP      %two_swap  ,
CODE 2OVER      %two_over  ,

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

CODE INVERT     %invert ,
CODE NEGATE     %negate ,

CODE 1+         %one_plus ,
CODE 1-         %one_minus ,
CODE 2*         %two_star ,
CODE 2/         %two_slash ,

CODE CELLS      %cells ,
CODE CELL+      %cell_plus ,

CODE COUNT      %count ,
CODE /STRING    %slash_string ,

CODE CMOVE      %cmove ,
CODE CMOVE>     %cmoveup ,
CODE MOVE       %move ,
CODE FILL       %fill ,

CODE SKIP       %skip ,     ( a n char -- a' n' )
CODE SCAN       %scan ,     ( a n char -- a' n' )

CODE COMP       %comp ,   ( a1 a2 n -- f )
CODE ICOMP      %icomp ,  ( a1 a2 n -- f )
CODE COMPARE    %compare ,

CODE >NUM       %tonum ,  ( ud a n base -- ud' a' n' )
CODE >BODY      %to_body ,

CODE ARGC       %argc , ( -- n )
CODE ARGV       %argv , ( n -- addr len )
CODE LIMIT      %limit , ( -- addr )
CODE BIOS       %bios , ( ??? svc -- ??? )

\ ============================================================
\ Target compiling words

T: ;        ?CSP  [TARGET] ;S  [TARGET] [  T;
T: LITERAL  ?EXEC  [TARGET] LIT  ,  T;
T: $        BL WORD NUMBER  [TARGET] LITERAL  T;
T: [CHAR]   CHAR  [TARGET] LITERAL  T;
T: [']      T'  [TARGET] LITERAL T;
T: [COMPILE]    T' DW, T;

T: "        [TARGET] (")  ,"  DWALIGN  T;

T: IF       [TARGET] ?BRANCH  >MARK  T;
T: THEN     >RESOLVE  T;
T: ELSE     [TARGET] BRANCH  >MARK  2SWAP >RESOLVE  T;
T: BEGIN    <MARK  T;
T: UNTIL    [TARGET] ?BRANCH  <RESOLVE  T;
T: AGAIN    [TARGET] BRANCH   <RESOLVE  T;
T: WHILE    [TARGET] IF  2SWAP  T;
T: REPEAT   [TARGET] AGAIN  [TARGET] THEN  T;

\ ============================================================
\ Misc.

0 CONSTANT 0
1 CONSTANT 1

TRUE  CONSTANT TRUE
FALSE CONSTANT FALSE

: ON  ( a -- )  TRUE  SWAP ! ;
: OFF ( a -- )  FALSE SWAP ! ;

: PLACE ( a n dest -- )  2DUP C!  1+ SWAP CMOVE ; \ doesn't handle overlap

: ALIGNED   ( a -- a' )  $ 7 + $ -8 AND ; \ 8-byte cell alignment
: DWALIGNED ( a -- a' )  $ 3 + $ -4 AND ; \ 4-byte (Double-Word) alignment for IP

\ ============================================================
\ BIOS: System

: BYE   0 0 BIOS ;

\ todo: could these be BIOS calls?

\  CODE GETENV  ( name len -- value len )  top = get_env(S, top); NEXT
\  CODE SETENV  ( value len name len -- )  set_env(S, top); S += 3, pop; NEXT

\ Dynamic Libraries
\  CODE DLOPEN  ( name len -- handle )
\  CODE DLCLOSE ( handle -- )
\  CODE DLSYM ( name len handle -- sym )
\  CODE DLERROR ( -- addr len )
\  CODE DLCALL ( <args> #args sym -- result )

\ ============================================================
\ BIOS: Terminal I/O

: KEY       ( -- char )     $ 1 BIOS ;
: EMIT      ( char -- )     $ 2 BIOS ;
: TYPE      ( a n --)       $ 3 BIOS ;
: ACCEPT    ( a n -- n )    $ 4 BIOS ;

$20 CONSTANT BL

: CR        $ A EMIT ;
: SPACE     BL EMIT ;

: (.")   R> COUNT  2DUP + DWALIGNED >R  TYPE ;
T: ."    [TARGET] (.")  ,"  DWALIGN  T;

\ for bringup
: X.   ( n -- )  1 $ 5 BIOS SPACE ;
: DUMP ( a n -- )  $ 6 BIOS ;

: DEPTH  SP@ SP0 @ SWAP -  1 CELLS / ; \ todo: code?
: .S  depth x. ." -> "
    sp@  sp0 @ $ 8 -  begin  2dup u> not while  dup @ x.  $ 8 -  repeat 2drop ;

\ ============================================================
\ BIOS: File I/O using stdio
\   mode    create  open
\   r/o     r       r
\   w/o     w       r+ (best we can do)
\   r/w     w+      r+

0 CONSTANT R/O  \ r
1 CONSTANT W/O  \ w
\ 2 is r+
3 CONSTANT R/W  \ w+

: CREATE-FILE ( a u fam -- fid ior )  $ 10 BIOS ;
: OPEN-FILE   ( a u fam -- fid ior )  DUP IF DROP $ 2 ( r+ ) THEN  CREATE-FILE ;
: CLOSE-FILE  ( fid -- ior )          $ 11 BIOS ;
: READ-FILE   ( a u fid -- u' ior )   $ 12 BIOS ;
: READ-LINE   ( a u fid -- u' f ior ) $ 13 BIOS ;
: WRITE-FILE  ( a u fid -- ior )      $ 14 BIOS ;
: WRITE-LINE  ( a u fid -- ior )      $ 15 BIOS ;

\ ============================================================
\ Dictionary

VARIABLE DP

: HERE      DP @  ;
: ALLOT     DP +! ;
: ,         HERE !    $ 8 DP +! ;
: C,        HERE C!     1 DP +! ;
: W,        HERE W!   $ 2 DP +! ;
: DW,       HERE DW!  $ 4 DP +! ;

: ALIGN     DP @  ALIGNED    DP ! ;
: DWALIGN   DP @  DWALIGNED  DP ! ;

: PAD ( -- addr )  HERE  $ 100 + ;

: COMPILE, ( xt -- )  DW, ;

: COMPILE ( -- )  R> DUP $ 4 + >R   DW@  DW, ;

\ ============================================================
\ Catch/throw implementation from standard:
\ https://forth-standard.org/standard/exception/CATCH

VARIABLE HANDLER

: CATCH ( xt -- exception# | 0 )
    SP@ >R             ( xt )       \ save data stack pointer
    HANDLER @ >R       ( xt )       \ and previous handler
    RP@ HANDLER !      ( xt )       \ set current handler
    EXECUTE            ( )          \ execute returns if no THROW
    R> HANDLER !       ( )          \ restore previous handler
    R> DROP            ( )          \ discard saved stack ptr
    0 ;                ( 0 )        \ normal completion

: THROW ( ??? exception# -- ??? exception# )
    ?DUP IF          ( exc# )     \ 0 THROW is no-op
      HANDLER @ RP!   ( exc# )     \ restore prev return stack
      R> HANDLER !    ( exc# )     \ restore prev handler
      R> SWAP >R      ( saved-sp ) \ exc# on return stack
      SP! DROP R>     ( exc# )     \ restore stack
      \ Return to the caller of CATCH because return
      \ stack is restored to the state that existed
       \ when CATCH began execution
    THEN ;

VARIABLE MSG
: (ABORT") ( f -- )
    IF  R@ MSG !  $ -2 THROW  THEN  R> COUNT + DWALIGNED >R ( skip" );

T: ABORT"    [TARGET] (ABORT")  ,"  DWALIGN  T;

\ ============================================================
\ Input source handling

VARIABLE 'IN    ( current source, points to source struct below )

$100 CONSTANT #TIB  ( max input line )

: >IN       'IN @ ;                 \ offset into source
: 'SOURCE   >IN     CELL+ ;         \ source length & address
: FID       >IN $ 3 CELLS + ;       \ file id
: LINE#     >IN $ 4 CELLS + ;       \ line # being interpreted
: TIB       >IN $ 5 CELLS + ;       \ text input buffer
: FNAME     TIB #TIB + ;            \ filename when including, c-str

5 CELLS  #TIB 2* +  CONSTANT #SOURCE  ( size of each source entry )

: SOURCE    ( -- a n )  'SOURCE 2@ ;
: SOURCE-ID ( -- fid | 0 | -1 )  FID @ ;

\ Source buffers at top of memory, above stack
: FIRST ( -- in0 )  LIMIT  [ 8 ( entries ) #SOURCE * ] LITERAL - ;

: SOURCE-DEPTH ( -- n )  >IN FIRST -  #SOURCE / ;

: INIT-SOURCE   >IN OFF   TIB 0 'SOURCE 2!   0 0 FID 2! ;

: >SOURCE ( fname len fid | -1 -- )
    >IN #SOURCE + LIMIT U> ABORT" source stack overflow"
    #SOURCE 'IN +!  INIT-SOURCE
    DUP FID !  0> IF  FNAME PLACE  THEN ;

: SOURCE> ( -- )
    >IN #SOURCE - FIRST U< ABORT" source stack empty"
    SOURCE-ID 0> IF  SOURCE-ID CLOSE-FILE DROP  THEN
    #SOURCE NEGATE 'IN +! ;

: REFILL-TIB ( -- f )
    TIB #TIB ACCEPT   DUP 0 >IN 2!   0< NOT ;
    
: REFILL-FILE ( -- f )
    TIB #TIB SOURCE-ID READ-LINE ( len flag ior )
    ROT 0 >IN 2!  1 LINE# +! 
    SWAP INVERT OR NOT ; ( not eof or error )

: REFILL ( -- f )
    SOURCE-ID 0< IF ( evaluate )  FALSE EXIT  THEN
    SOURCE-ID IF  REFILL-FILE  ELSE  REFILL-TIB  THEN ;

: QUERY  INIT-SOURCE  REFILL-TIB 0= IF BYE THEN ;

\ ============================================================
\ Parsing

: (PARSE) ( char skip? -- a n )
    SWAP >R  SOURCE  >IN @ /STRING
    ROT IF  R@ SKIP  THEN  OVER SWAP  R> SCAN
    DUP IF 1- THEN  'SOURCE @ SWAP - >IN !  OVER - ;

: PARSE      ( char -- a n )    0 (PARSE) ;
: PARSE-WORD ( char -- a n )    1 (PARSE) ;
: PARSE-NAME ( -- a n )         BL PARSE-WORD ;

: WORD ( char -- here )
    PARSE-WORD  HERE PLACE  HERE  BL OVER COUNT + C! ;

\ ============================================================
\ Number input conversion, single-cell integers only.
\ The input is a counted, blank-terminated string, like the output of WORD.
\ We ignore the count and rely instead on the blank terminator.
\ Supports the standard 'c' and base prefixes #, $ and %.

VARIABLE BASE

CODE DIGIT %digit , ( char base -- n f )

: NUMBER ( c-str -- n )   1+
    ( check for 'c' )
    DUP C@ [CHAR] ' = IF  1+  C@ EXIT  THEN ( lax )

    ( check base prefix )
    DUP C@ [CHAR] # = IF  1+  $ 0A  ELSE
    DUP C@ [CHAR] $ = IF  1+  $ 10  ELSE
    DUP C@ [CHAR] % = IF  1+  $ 02  ELSE  BASE @  THEN THEN THEN
    >R ( base )

    ( check sign )
    DUP C@ [CHAR] - =  DUP 2* 1+ ( sign 1/-1 )  R>  2>R  ( r: sign base )
    NEGATE + ( skip '-' )

    ( any digits left? )  DUP C@ BL = ABORT" ?"

    ( convert and accumulate digits until a blank )
    0 ( n ) SWAP
    BEGIN   COUNT  DUP BL > WHILE
        R@ DIGIT 0= ABORT" ?"  ROT R@ * + SWAP ( accum )
    REPEAT
    2DROP  2R> DROP ( sign ) * ;

\ ============================================================
\ Dictionary search (case insensitive)
\
\   | name(1-31) | count(1) | link(4) | code(8) | parameters (0+) |
\
\ The code and parameter fields are 8-byte aligned.
\ The link field is the xt of the previous definition or zero.

: XT  ( cfa -- xt )  ORIGIN -  $ 3 RSHIFT ;
: CFA ( xt -- cfa )  $ 3 LSHIFT  ORIGIN + ;

: LFA ( xt -- lfa )  CFA $ 4 - ;
: NFA ( xt -- nfa )  CFA $ 5 - ;

: .NFA ( nfa -- )  DUP C@ $ 1F AND  TUCK - SWAP  TYPE SPACE ;

: MATCH ( a n nfa -- 0|1|-1 )
    2DUP C@ $ 3F AND - IF ( diff. len )  DROP 2DROP  0 EXIT  THEN
    DUP C@ >R ( count byte )
    OVER - ( name ) SWAP ICOMP IF ( mismatch )  R> DROP  0 EXIT  THEN
    R> $ 80 AND ( imm? ) 0=  1 OR ;

: SEARCH-WORDLIST ( c-addr u wid -- 0 | xt 1 | xt -1 )
    @ BEGIN  DUP WHILE ( a n xt )
        >R  2DUP R@ NFA MATCH  ?DUP IF  >R  2DROP  2R>  EXIT  THEN
        R>  LFA DW@ ( next )
    REPEAT  NIP NIP ;

\ ============================================================
\ Search order

VARIABLE CONTEXT   0 , 0 , 0 , 0 , 0 , 0 , 0 , ( end ) 0 ,
VARIABLE CURRENT   0 , ( initial forth wordlist )

: FIND ( addr -- addr 0 | xt 1 | xt -1 )
    CONTEXT BEGIN  DUP @ WHILE
        DUP 2@ - IF ( skip duplicates )
            >R  DUP COUNT R@ @ SEARCH-WORDLIST
            ?DUP IF  ROT R> 2DROP  EXIT THEN
            R>
        THEN CELL+
    REPEAT  @ ( 0 ) ;

: DEFINED ( -- here 0 | xt 1 | xt -1 )  BL WORD FIND ;
: '  ( -- xt )  DEFINED 0= ABORT" ?" ;

: WORDS ( -- )  0  CONTEXT @ @
    BEGIN ?DUP WHILE  DUP NFA .NFA  LFA DW@  SWAP 1+ SWAP  REPEAT X. ;

\ ============================================================
\ Interpreter

VARIABLE STATE

: ?STACK
    SP@ SP0 @ U> ABORT" stack underflow"
    SP@ PAD   U< ABORT" stack overflow" ;

: INTERPRET  ( -- ) \ exits at end of input or via throw
    BEGIN   BL WORD  DUP C@ WHILE
        FIND  ?DUP IF
            STATE @ = IF  COMPILE,  ELSE  EXECUTE  ?STACK  THEN
        ELSE
            NUMBER  STATE @ IF  COMPILE LIT  ,  THEN
        THEN
    REPEAT DROP ;

\ ============================================================
\ Load from a file

VARIABLE ERR 0 , \ error location
: ?ERR ( n -- n )  DUP ERR @ 0= AND IF  LINE# @ FNAME ERR 2!  THEN ;

: (INCLUDE)  BEGIN REFILL WHILE INTERPRET REPEAT ;

: INCLUDE-FILE  ( str len fid -- )  >SOURCE  HANDLER @
    IF  ['] (INCLUDE) CATCH ?ERR  SOURCE> THROW  ELSE  (INCLUDE) SOURCE>  THEN ;

: INCLUDED  ( str len -- )
    2DUP R/O OPEN-FILE IF  DROP HERE PLACE  TRUE ABORT" file not found"  THEN
    INCLUDE-FILE ;

: INCLUDE   PARSE-NAME INCLUDED ;

: EVALUATE ( addr len -- )  $ -1 >SOURCE  'SOURCE 2!  HANDLER @
    IF  ['] INTERPRET CATCH  SOURCE> THROW  ELSE  INTERPRET SOURCE>  THEN ;

\ ============================================================
\ QUIT loop

: .ERROR ( n -- )  DUP $ -1 = IF ( no msg for ABORT ) DROP EXIT  THEN
    ERR @ IF  ERR 2@  CR COUNT TYPE ." :" 1 $ 5 BIOS ." : "  ERR OFF  THEN
    HERE COUNT TYPE SPACE
    DUP $ -2 = IF  DROP  MSG @ COUNT TYPE SPACE  ELSE  ." Error " X.  THEN ;

: INTERPRETER
    BEGIN  CR QUERY  INTERPRET  STATE @ 0= IF ."  ok" THEN  AGAIN ;

: QUIT
    RP0 @ RP!  FIRST 'IN ! ( leaves files open )
    BEGIN
        STATE OFF
        ['] INTERPRETER CATCH .ERROR
        SP0 @ SP!
    AGAIN ;

\ ============================================================
\ Build headers

VARIABLE WARNINGS
: WARN   WARNINGS @ IF  >IN @  DEFINED NIP IF
    HERE COUNT TYPE ."  redefined " THEN  >IN !  THEN ;

: NAME, ( addr len -- )
    BEGIN  DUP HERE +  $ 5 +  $ 7 AND WHILE  $ FF C,  REPEAT ( pre-align cfa )
    TUCK  HERE SWAP  DUP ALLOT  CMOVE  C, ;

VARIABLE LAST ( xt of latest word )
: HEADER ( -- ) \ build name and link
    WARN  PARSE-NAME NAME,
    CURRENT @  DUP @ DW,  HERE XT  DUP LAST !  SWAP ! ;

: PRIOR ( -- nfa count )  LAST @ NFA  DUP C@ ;
: SMUDGE     PRIOR  $ 20 XOR  SWAP C! ; \ toggle
: IMMEDIATE  PRIOR  $ 80 OR   SWAP C! ;

\ ============================================================
\ Defining words

: CREATE    HEADER  [ %docreate   ] LITERAL ,  0 , ;
: CONSTANT  HEADER  [ %doconstant ] LITERAL ,    , ;
: VARIABLE  HEADER  [ %dovariable ] LITERAL ,  0 , ;
: DEFER     HEADER  [ %dodefer    ] LITERAL ,  0 , ;

: ]         STATE ON ;
: :         HEADER  [ %docolon ] LITERAL ,  SMUDGE  ] ;
: :NONAME   ALIGN  0 ,  HERE XT  DUP LAST !  [ %docolon ] LITERAL ,  ] ;
: RECURSE   LAST @ COMPILE, ; IMMEDIATE

\ todo: DOES> must end any locals
\ : ;DOES     R>  LAST @ CFA CELL+ ! ;
\ : DOES>     ( end locals )  COMPILE ;DOES  ( init locals ) ; IMMEDIATE
: DOES>     R>  LAST @ CFA CELL+ ! ;

\ ============================================================
\ Startup

HERE ," Hello" CONSTANT GREETING

\ Process command-line arguments
\ -e <string>   evaluate string
\ <filename>    include file
: DOARGS ( -- )
    1 BEGIN DUP ARGC < WHILE
        DUP >R ARGV
        OVER C@ [CHAR] - = IF  1 /STRING
            OVER C@ [CHAR] e = IF
                R> 1+ DUP >R  ARGC < IF
                    R@ ARGV EVALUATE
                THEN
            ELSE
                CR ." Unknown option -" OVER C@ EMIT CR
            THEN
            2DROP
        ELSE
            INCLUDED
        THEN
        R> 1+
    REPEAT DROP ;

: COLD ( -- )
    FIRST $ 100 - SP! ( put stack below input buffers )
    SP@ SP0 !  RP@ RP0 !  FIRST 'IN !
    ['] DOARGS CATCH  ?DUP IF  DUP .ERROR CR  NEGATE 0 BIOS  THEN
    GREETING COUNT TYPE  QUIT ;

: WARM ( sig -- )
    .ERROR
    FIRST $ 100 - SP! ( put stack below input buffers )
    SP@ SP0 !  RP@ RP0 !  FIRST 'IN !
    QUIT ;

( do this last! )
: ;   COMPILE ;S  SMUDGE  STATE OFF  ;S [ IMMEDIATE

T' COLD DATA-ORIGIN T!
T' WARM DATA-ORIGIN CELL+ T!
HERE DP T!
#10 BASE T!

CURRENT CELL+ ( forth wordlist )
LATEST @ OVER T!
DUP CONTEXT T! CURRENT T!
