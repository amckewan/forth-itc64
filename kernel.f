\ ITC-64 Forth Kernel

HERE 0 , \ cold start xt
HERE 0 , \ warm start xt (after exception)

%origin CONSTANT ORIGIN

CONSTANT 'WARM
CONSTANT 'COLD

\ todo: user variables
VARIABLE SP0
VARIABLE RP0

\ ============================================================
\ Code words implemented in kernel.asm

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
CODE LIT32      %lit32 ,
CODE (")        %litq ,

CODE +          %plus ,
CODE -          %minus ,
CODE *          %star ,
CODE /          %slash ,

CODE UM*        %um_star ,
CODE UM/MOD     %um_slash_mod ,
CODE M*         %m_star ,
CODE SM/REM     %sm_slash_rem ,
CODE /MOD       %slash_mod ,
CODE */MOD      %star_slash_mod ,

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

CODE MOVE       %move ,
CODE CMOVE      %cmove ,
CODE CMOVE>     %cmoveup ,
CODE FILL       %fill ,
CODE COMP       %comp ,
CODE COMPARE    %compare ,

\ ============================================================
\ Target compiling words

t: ;        ?csp  [target] ;S  [target] [  t;
t: literal  ?exec  [target] LIT  ,  t;
t: $        bl word number drop  [target] literal  t;
t: [']      t'  [target] literal t;
t: [compile]    t' dw, t;

t: "        [target] (")  ,"  XT-ALIGN  t;

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

: ON  ( a -- )  TRUE  SWAP ! ;
: OFF ( a -- )  FALSE SWAP ! ;

: PLACE ( a n dest -- )  2DUP C!  1+ SWAP CMOVE ; \ doesn't handle overlap

: ALIGNED    ( xxxxx -- yy000 )  $ 7 + $ -8 AND ; \ 8-byte cell alignment
: XT-ALIGNED ( xxxxx -- yyy00 )  $ 3 + $ -4 AND ; \ 4-byte alignment for IP

\ ============================================================
\ BIOS: System

CODE BIOS   %bios , ( ??? svc -- ??? )

: BYE   0 0 BIOS ;

\ todo: could these be BIOS calls?
CODE ARGC   %argc ,     ( -- n )
CODE ARGV   %argv ,     ( n -- addr len )

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

: (.")   R> COUNT  2DUP + XT-ALIGNED >R  TYPE ;
T: ."    [TARGET] (.")  ,"  XT-ALIGN  T;

\ for bringup
: H. ( u -- )  0 $ 5 BIOS SPACE ;
: .  ( n -- )  1 $ 5 BIOS SPACE ;
: ?  @ . ;
: DUMP ( a n -- )  $ 6 BIOS ;

: DEPTH  SP@ SP0 @ SWAP -  1 CELLS / ; \ todo: code?
: .S  depth . ." -> "
    sp@  sp0 @ $ 8 -  begin  2dup u> not while  dup @ .  $ 8 -  repeat 2drop ;

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

: ALIGN     HERE    ALIGNED DP ! ;
: XT-ALIGN  HERE XT-ALIGNED DP ! ;

: COMPILE, ( xt -- )  DW, ;

: COMPILE ( -- )  R>   DUP $ 4 + >R   DW@ DW, ;

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
    IF  R@ MSG !  $ -2 THROW  THEN  R> COUNT + XT-ALIGNED >R ( skip" );

T: ABORT"    [TARGET] (ABORT")  ,"  XT-ALIGN  T;

\ ============================================================
\ Input source handling

VARIABLE 'IN    ( current source, points to source struct below )

$100 CONSTANT #TIB  ( max input line )

: >IN       'IN @ ;                 \ offset into source
: 'SOURCE   >IN     CELL+ ;         \ source length & address
: FID       >IN $ 3 CELLS + ;       \ file id
: LINE#     >IN $ 4 CELLS + ;       \ line # being interpreted
: TIB       >IN $ 5 CELLS + ;       \ text input buffer
: FNAME      TIB #TIB + ;           \ filename when including, c-str

5 CELLS  #TIB 2* +  CONSTANT #SOURCE  ( size of each source entry )

: SOURCE    ( -- a n )  'SOURCE 2@ ;
: SOURCE-ID ( -- fid | 0 | -1 )  FID @ ;

\ Source buffers at top of memory, above stack (fingers crossed)
CODE LIMIT  %limit ,  ( -- addr ) \ top of memory
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

: REFILL ( -- f )  \ push refill(SOURCE); NEXT
    SOURCE-ID 0< IF ( evaluate )  FALSE EXIT  THEN
    SOURCE-ID IF  REFILL-FILE  ELSE  REFILL-TIB  THEN ;

: QUERY  INIT-SOURCE  REFILL 0= IF BYE THEN ;

\ ============================================================
\ Parsing

: SKIP ( a n char -- a' n' )
    >R  BEGIN  OVER C@ R@ =  OVER AND WHILE  1 /STRING  REPEAT  R> DROP ;
: SCAN ( a n char -- a' n' )
    >R  BEGIN  OVER C@ R@ = NOT  OVER AND WHILE  1 /STRING  REPEAT  R> DROP ;
: ADVANCE ( a a' n' -- a n )
    DUP IF 1- THEN  'SOURCE @ SWAP - >IN !  OVER - ;

: PARSE ( char -- a n )
    >R  SOURCE  >IN @ /STRING  OVER SWAP  R> SCAN  ADVANCE ;
: PARSE-WORD ( char -- a n ) \ skip leading delimeters
    >R  SOURCE  >IN @ /STRING  R@ SKIP  OVER SWAP  R> SCAN  ADVANCE ;
: PARSE-NAME ( -- a n ) \ whitespace delimiter, skip leading
    SOURCE  >IN @ /STRING
    ( skip ) BEGIN  DUP WHILE  OVER C@ BL > NOT WHILE  1 /STRING  REPEAT THEN
    OVER SWAP ( a a' n' )
    ( scan ) BEGIN  DUP WHILE  OVER C@ BL >     WHILE  1 /STRING  REPEAT THEN
    ADVANCE ;

: WORD ( char -- here )
    DUP BL = IF  DROP PARSE-NAME  ELSE  PARSE-WORD  THEN
    HERE PLACE  HERE ;

\ ============================================================
\ Number input

T: [CHAR]   CHAR  [TARGET] LITERAL  T;

VARIABLE BASE

CODE >NUM  %tonum ,  ( ud a n base -- ud' a' n' )
: >NUMBER ( ud a n -- ud' a' n' )  BASE @ >NUM ;

: NUMBER? ( addr len -- n f ) \ single-precision only
    DUP $ 3 = IF ( check for 'c' )
        OVER COUNT [CHAR] ' =  SWAP 1+ C@ [CHAR] ' = AND
        IF  DROP 1+ C@  TRUE EXIT  THEN
    THEN

    ( check for base prefix )
    OVER C@ [CHAR] # = IF  1 /STRING  $ 0A  ELSE
    OVER C@ [CHAR] $ = IF  1 /STRING  $ 10  ELSE
    OVER C@ [CHAR] % = IF  1 /STRING  $ 02  ELSE  BASE @  THEN THEN THEN
    >R ( base )

    ( check sign )
    OVER C@ [CHAR] - =   DUP 2* 1+ ( -1/1 )  R>  2>R  ( r: sign base )
    NEGATE /STRING ( skip '-' )

    DUP 0> IF ( convert digits )  0 0 2SWAP  R@ >NUM  NIP NIP 0= ( n f )
    ELSE  ( no chars left )  2DROP  0 FALSE
    THEN  2R> DROP ( sign )  ROT * SWAP ;

: NUMBER ( addr len -- n )   NUMBER? NOT ABORT" ?" ;

\ ============================================================
\ Dictionary search
\
\   | name(1-31) | count(1) | link(4) | code(8) | parameters (0+) |
\
\ The code and parameter fields are 8-byte aligned.
\ The link field is the xt of the previous definition or zero.

\  : xt  ( cfa -- xt )  origin - $ 3 rshift ;

: CFA ( xt -- cfa )  $ 3 LSHIFT  ORIGIN + ;
: LFA ( xt -- lfa )  CFA $ 4 - ;
: NFA ( xt -- nfa )  CFA $ 5 - ;

: >NAME ( xt -- name count )  NFA  DUP C@  SWAP OVER $ 1F AND -  SWAP ;
: .NAME ( xt -- )  >NAME $ 1F AND TYPE SPACE ;

: MATCH ( a n nfa -- 0|1|-1 )
    2dup c@ $ 3f and - if ( diff. len )  drop 2drop  0 exit  then
    dup c@ >r ( count byte )
    over - ( name ) swap comp if ( mismatch )  r> drop  0 exit  then
    r> $ 80 and 0= invert ( imm? )  2* 1+ negate ( -1/1 ) ;

: SEARCH-WORDLIST ( c-addr u wid -- 0 | xt 1 | xt -1 )
    @ begin  dup while ( a n xt )
        >r  2dup r@ nfa match  ?dup if  >r  2drop  2r>  exit  then
        r>  lfa dw@ ( next )
    repeat  nip nip ;

\ ============================================================
\ Search order

\ VARIABLE FORTH-WORDLIST

VARIABLE CONTEXT   0 , 0 , 0 , 0 , 0 , 0 , 0 , ( end ) 0 ,
VARIABLE CURRENT   0 , ( initial forth wordlist )

: FIND ( c-addr -- c-addr 0 | xt 1 | xt -1 )
    CONTEXT BEGIN  DUP @ WHILE
        2DUP  SWAP COUNT  ROT @ SEARCH-WORDLIST
          ?DUP IF  2SWAP 2DROP  EXIT  THEN
        CELL+
    REPEAT  @ ;

: WORDS ( -- )  context @ @
    begin ?dup while  dup .name  lfa dw@ repeat ;

\ ============================================================
\ Case sensitivity. This follows the F83 approach where dictionary
\ searching is case sensitive and the variable CAPS turns on
\ a virtual caps-lock system. When CAPS is on, all names are forced
\ to uppercase and words are converted to uppercase before searching.

: UPC ( c -- C )  DUP [CHAR] a [ CHAR z 1+ ] LITERAL WITHIN IF  BL -  THEN ;
: UPPER ( a n -- )  OVER + SWAP
    BEGIN  2DUP - WHILE  COUNT UPC  OVER 1- C!  REPEAT  2DROP ;
\    ?DO  I C@ UPC I C!  LOOP ;

VARIABLE CAPS   TRUE CAPS T!
: ?UPPERCASE ( str -- str )  \ modify string in-place
    CAPS @ IF  DUP COUNT UPPER  THEN ;

: FIND-NAME ( addr len -- here 0 | xt 1 | xt -1 )
    HERE PLACE  HERE ?UPPERCASE FIND ;
: DEFINED ( -- here 0 | xt 1 | xt -1 )
    PARSE-NAME FIND-NAME ;

: '  ( -- xt )  DEFINED 0= ABORT" ?" ;

\ ============================================================
\ Interpreter

: PAD  HERE $ 100 + ;
: ?STACK
    SP@ SP0 @ U> ABORT" stack underflow"
    SP@ PAD   U< ABORT" stack overflow" ;


VARIABLE STATE
: INTERPRET  ( -- ) \ exits at end of input or via throw
    BEGIN   PARSE-NAME   DUP WHILE
        2DUP FIND-NAME  ?DUP IF  2SWAP 2DROP ( discard a/n )
            STATE @ = IF  COMPILE,  ELSE  EXECUTE  ?STACK  THEN
        ELSE ( a n here )
            DROP NUMBER  STATE @ IF  COMPILE LIT  ,  THEN
        THEN
    REPEAT 2DROP ;

VARIABLE ERR 0 , \ error location
: ?ERR ( n -- n )  DUP ERR @ 0= AND IF  LINE# @ FNAME ERR 2!  THEN ;

: (INCLUDE)  BEGIN REFILL WHILE INTERPRET REPEAT ;

: INCLUDE-FILE  ( str len fid -- )  >SOURCE  HANDLER @
    IF  ['] (INCLUDE) CATCH ?ERR  SOURCE> THROW  ELSE  (INCLUDE) SOURCE>  THEN ;

: INCLUDED  ( str len -- )
    2DUP R/O OPEN-FILE ABORT" file not found" INCLUDE-FILE ;

: INCLUDE  PARSE-NAME INCLUDED ;

\ ============================================================
\ Build headers

VARIABLE WARNINGS
: WARN   WARNINGS @ IF  >IN @  DEFINED IF
    HERE COUNT TYPE ."  redefined " THEN  DROP >IN !  THEN ;

: PREALIGN ( -- ) \ align so next word will have aligned cfa
    >IN @  PARSE-NAME NIP 1+  SWAP >IN !
    BEGIN  HERE OVER +  $ 4 +  $ 7 AND WHILE  $ FF C,  REPEAT DROP ;

: XT ( cfa -- xt )  ORIGIN - $ 3 RSHIFT ;

: NAME, ( a n -- )
    >R  HERE R@ CMOVE  CAPS @ IF  HERE R@ UPPER  THEN  R> DUP ALLOT C, ;

: HEADER ( -- ) \ build name and link
    WARN  PREALIGN  PARSE-NAME NAME,
    CURRENT @  DUP @ DW,  HERE XT SWAP ! ;

: PRIOR ( -- nfa count )  CURRENT @ @ NFA  DUP C@ ;
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

\ todo: DOES> must end any locals
: ;DOES     R>  [ %dodoes ] LITERAL  CURRENT @ @ CFA 2! ;
: DOES>     COMPILE ;DOES ; IMMEDIATE

CODE >BODY ( xt -- addr )  %to_body ,  \ CFA CELL+ CELL+ ;

\ We want DOES> and RECURSE to work in :NONAME
\  : :NONAME  ALIGN HERE XT  [ %docolon ] LITERAL ,  LAST OFF  ] ;
\  : RECURSE  CURRENT @ @ COMPILE, ; IMMEDIATE

\ ============================================================
\ Interpreter

: .ERROR ( n -- )
    ERR @ IF  ERR 2@  CR COUNT TYPE ." :" 1 $ 5 BIOS ." : "  ERR OFF  THEN
    HERE COUNT TYPE SPACE
    DUP $ -2 = IF  DROP  MSG @ COUNT TYPE SPACE  ELSE  ." Error " .  THEN ;

: INTERPRETER
    BEGIN  CR QUERY  INTERPRET  STATE @ 0= IF ."  ok" THEN  AGAIN ;

: QUIT
    RP0 @ RP!  FIRST 'IN !
    BEGIN
        STATE OFF
        ['] INTERPRETER CATCH .ERROR
        SP0 @ SP!
    AGAIN ;

HERE ," Hello!" CONSTANT GREETING

: COLD
    LIMIT $ 2008 - SP! ( leave 8K for input buffers )
    SP@ SP0 !  RP@ RP0 !
    GREETING COUNT TYPE  QUIT ;

( do this last! )
: ;   COMPILE ;S  SMUDGE  STATE OFF  ;S [ IMMEDIATE

T' COLD DATA-ORIGIN T!
HERE DP T!
#10 BASE T!

CURRENT CELL+ ( forth wordlist )
LATEST @ OVER T!
DUP CONTEXT T! CURRENT T!

\  LATEST @ FORTH-WORDLIST T!
\  FORTH-WORDLIST CONTEXT T!
\  FORTH-WORDLIST CURRENT T!
