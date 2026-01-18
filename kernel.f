\ ITC-64 Forth Kernel

0 , \ cold start xt
0 , \ warm start xt (after exception)
0 , \ SP0
0 , \ RP0

%origin CONSTANT ORIGIN
DATA-ORIGIN CONSTANT DP0

DATA-ORIGIN 0 cells + CONSTANT 'COLD
DATA-ORIGIN 1 cells + CONSTANT 'WARM
DATA-ORIGIN 2 cells + CONSTANT SP0
DATA-ORIGIN 3 cells + CONSTANT RP0

\ ============================================================
\ Code words implemented in kernel.asm

CODE ;S         %unnest ,
CODE EXIT       %unnest ,
CODE EXECUTE    %execute ,
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
t: [']      t'  [target] literal t;
t: [compile]    t' dw, t;

t: "        [target] (")  ,"  4ALIGN  t;

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

: */   */MOD NIP ;
: MOD  /MOD DROP ;

: PLACE ( a n dest -- )   2DUP C!  1+ SWAP CMOVE ;

: ALIGNED  ( a -- a' )   $ 7 + $ -8 AND ;
: 4ALIGNED ( a -- a' )   $ 3 + $ -4 AND ;

\ ============================================================
\ BIOS: System

CODE BIOS   %bios , ( ??? svc -- ??? )

: BYE   0 0 BIOS ;

CODE ARGC   %argc ,     ( -- n )
CODE ARGV   %argv ,     ( n -- str len )

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

: (.")   R> COUNT  2DUP + 4ALIGNED >R  TYPE ;
T: ."    [TARGET] (.")  ,"  4ALIGN  T;

\ for bringup
: H. ( u -- )  0 $ 5 BIOS SPACE ;
: .  ( n -- )  1 $ 5 BIOS SPACE ;
: ?  @ . ;
: DUMP ( a n -- )  $ 6 BIOS ;

: DEPTH  SP@ SP0 @ SWAP -  1 CELLS / ;
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
\ BIOS: Memory allocation

: ALLOCATE   ( n -- a ior )      $ 20 BIOS ;
: RESIZE     ( a n -- a' ior )   $ 21 BIOS ;
: FREE       ( a -- ior )        $ 22 BIOS ;

\ Allocate counted and null-terminate string
\  : NEW-STRING ( adr len -- c-str )
\      DUP 1+ 1+ ALLOCATE DROP >R
\      DUP R@ C! ( count )
\      0 OVER R@ 1+ + C! ( null term. )
\      R@ 1+ SWAP CMOVE ( string ) R> ;

\ ============================================================
\ Dictionary

VARIABLE DP

: HERE      DP @  ;
: ALLOT     DP +! ;
: ,         HERE !    $ 8 DP +! ;
: C,        HERE C!     1 DP +! ;
: W,        HERE W!   $ 2 DP +! ;
: DW,       HERE DW!  $ 4 DP +! ;

: ALIGN     HERE  ALIGNED DP ! ;
: 4ALIGN    HERE 4ALIGNED DP ! ;

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
    IF  R@ MSG !  $ -2 THROW  THEN  R> COUNT + 4ALIGNED >R ;

T: ABORT"    [TARGET] (ABORT")  ,"  4ALIGN  T;

\ kernel.f:8: Undefined word

\ ============================================================
\ Input source handling

VARIABLE 'IN    ( current source, points to source struct below )

$100 CONSTANT #TIB  ( max input line )

: >IN       'IN @ ;                 \ offset into source
: 'SOURCE   'IN @ CELL+ ;           \ source length & address
: FID       'IN @ $ 3 CELLS + ;     \ file id
: LINE#     'IN @ $ 4 CELLS + ;     \ line # being interpreted
: TIB       'IN @ $ 5 CELLS + ;     \ text input buffer
: FNAME      TIB #TIB + ;           \ filename when including

#TIB 2* 5 CELLS + CONSTANT #SOURCE  ( size of each source entry )

\ todo: create in high memory
CREATE SOURCE-STACK    8 ( entries ) #SOURCE * ALLOT

: SOURCE        'SOURCE 2@ ;
: SOURCE-ID     FID @ ;

: SOURCE-DEPTH  >IN SOURCE-STACK -  #SOURCE / ;

: INIT-SOURCE   >IN OFF   TIB 0 'SOURCE 2!   0 0 FID 2! ;

: >SOURCE ( fname len fid | -1 -- )
\    SOURCE-DEPTH $ 7 U> ABORT" source nested too deeply"
    #SOURCE 'IN +!  INIT-SOURCE
    DUP FID !  0> IF  FNAME PLACE  THEN ;

: SOURCE> ( -- )
\    SOURCE-DEPTH 0= ABORT" trying to pop empty source"
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
    \  ( scan ) BEGIN  OVER C@ BL >      OVER AND WHILE  1 /STRING  REPEAT
    ADVANCE ;

: WORD ( char -- here )
    DUP BL = IF  DROP PARSE-NAME  ELSE  PARSE-WORD  THEN
    HERE PLACE HERE   BL OVER COUNT + C! ;

\ ============================================================
\ Number input

T: [CHAR]   CHAR  [TARGET] LITERAL  T;

: DIGIT ( char -- n )
    \  [CHAR] 0 - ;
    DUP [CHAR] 9 > IF  BL OR  [CHAR] a -  $ A +  ELSE  [CHAR] 0 -  THEN ;

CREATE BASE  #10 ,

: NUMBER? ( str -- n f )
    COUNT $ 3 =  OVER C@ [CHAR] ' = AND  OVER 1+ 1+ C@ [CHAR] ' = AND
    IF  ( 'c' ) 1+ C@  TRUE EXIT  THEN

    DUP C@ [CHAR] # = IF  1+  $ 0A  ELSE
    DUP C@ [CHAR] $ = IF  1+  $ 10  ELSE
    DUP C@ [CHAR] % = IF  1+  $ 02  ELSE  BASE @  THEN THEN THEN
    SWAP

    DUP C@ [CHAR] - =  DUP 2* 1+ >R  NEGATE +

    SWAP >R ( base ) 0 ( n ) SWAP
    BEGIN   COUNT  DUP BL > WHILE
        DIGIT  DUP R@ U< NOT IF  2DROP FALSE  2R> 2DROP EXIT  THEN
        ROT R@ * + SWAP
    REPEAT
    2DROP  2R> DROP *  TRUE ;

: >NUMBER ( ud a n -- ud' a' n' )  ;

\  : char? ( a n -- c 1 | 0 )
\      3 =  swap count [char] ' =  
\       swap 1+ c@ [char] ' = and  r> $ 3 = and

\      OVER C@ [CHAR] ' =  OVER 1+ 1+ C@ [chAR] ' = AND  OVER $ 3 = AND
\      IF ( 'c' )  DROP 1+ C@  TRUE EXIT  THEN

\  : set-base ( a n -- a' n' )
\      DUP 1 > IF
\          OVER C@ [CHAR] # = IF  $ 0A BASE !  1 /STRING  ELSE
\          OVER C@ [CHAR] $ = IF  $ 10 BASE !  1 /STRING  ELSE
\          OVER C@ [CHAR] % = IF  $ 02 BASE !  1 /STRING  THEN THEN THEN
\      THEN ;

: NUM2 ( a n -- n f )
    OVER C@ [CHAR] ' =  OVER 1+ 1+ C@ [CHAR] ' = AND  OVER $ 3 = AND
    IF ( 'c' )  DROP 1+ C@  TRUE EXIT  THEN

    BASE @ >R  DUP 1 > IF
        OVER C@ [CHAR] # = IF  $ 0A BASE !  1 /STRING  ELSE
        OVER C@ [CHAR] $ = IF  $ 10 BASE !  1 /STRING  ELSE
        OVER C@ [CHAR] % = IF  $ 02 BASE !  1 /STRING  THEN THEN THEN
    THEN

    OVER C@ [CHAR] - =  DUP 2* 1+ >R ( sign )
    OVER 1 > AND IF  1 /STRING  THEN

    0 0 2SWAP >NUMBER  0= NIP NIP ( n f )

    SWAP R> * SWAP   R> BASE ! ;


: NUMBER ( str -- n )   NUMBER? NOT ABORT" ?" ;

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
: NFA ( xt -- nfa )  LFA 1- ;

: >BODY ( xt -- pfa )  CFA CELL+ ;
: >NAME ( xt -- name count )  NFA  DUP C@  SWAP OVER $ 1F AND -  SWAP ;
: .NAME ( xt -- )  >NAME $ 1F AND TYPE SPACE ;

CODE COMP ( a1 a2 n -- 0/1/-1 )  %comp ,

: comp2  cr ." comp " >r  over r@ type space  dup r@ type space  r> comp ." -> " dup . ;

: MATCH ( a n nfa -- 0|1|-1 )
    2dup c@ $ 3f and - if ( diff. len )  drop 2drop  0 exit  then
    dup c@ >r ( count byte )
    over - ( name ) swap comp if ( mismatch )  r> drop  0 exit  then
    r> $ 80 and 0= invert ( imm? )  2* 1+ negate ( -1/1 ) ;

: SEARCH-WORDLIST ( c-addr u wid -- 0 | xt 1 | xt -1 )
    @ begin  dup while ( a n xt )  \ dup .name
        >r  2dup r@ nfa match  ?dup if  >r  2drop  2r>  exit  then
        r>  lfa dw@ ( next )
    repeat  nip nip ;

\ ============================================================
\ Search order

VARIABLE FORTH-WORDLIST

CREATE CONTEXT   FORTH-WORDLIST , 0 , 0 , 0 , 0 , 0 , 0 , 0 , ( end ) 0 ,
CREATE CURRENT   FORTH-WORDLIST ,

: FIND ( c-addr -- c-addr 0 | xt 1 | xt -1 )
    DUP COUNT  CONTEXT @ SEARCH-WORDLIST  DUP IF  ROT DROP  THEN ;

: find2 ( c-addr -- c-addr 0 | xt 1 | xt -1 )
    context begin  dup @ while
        2dup  swap count  rot @ search-wordlist
          ?dup if  2swap 2drop  exit  then
        cell+
    repeat  @ ;

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

\ ============================================================
\ Interpreter

: DEFINED ( -- here 0 | xt 1 | xt -1 )  BL WORD ?UPPERCASE FIND ;

\ : '  ( -- xt )  DEFINED NOT ABORT" ?" ;

: COMPILE, ( xt -- )  DW, ;

: ?STACK  DEPTH 0< ABORT" stack?" ;

VARIABLE STATE
: INTERPRET  ( -- )
    BEGIN  BL WORD ?UPPERCASE  DUP C@ WHILE  
        FIND ?DUP IF
            STATE @ = IF  COMPILE,  ELSE  EXECUTE  ?STACK  THEN
        ELSE
            NUMBER  STATE @ IF  LIT ,  THEN
        THEN
    REPEAT DROP ;

VARIABLE ERR 0 , \ error location
: ?ERR ( n -- n )  DUP ERR @ 0= AND IF  LINE# @ FNAME ERR 2!  THEN ;

: (INCLUDE)  BEGIN REFILL WHILE INTERPRET REPEAT ;

: INCLUDE-FILE  ( str len fid -- )  >SOURCE  HANDLER @
    IF  ['] (INCLUDE) CATCH ?ERR  SOURCE> THROW  ELSE  (INCLUDE) SOURCE>  THEN ;

: INCLUDED  ( str len -- )
    2DUP R/O OPEN-FILE ABORT" file not found" INCLUDE-FILE ;

: INCLUDE  PARSE-NAME INCLUDED ;


\ ============================================================
\ test

: .ERROR ( n -- )
    ERR @ IF  ERR 2@  CR COUNT TYPE ." :" 1 $ 5 BIOS ." : "  ERR OFF  THEN
    HERE COUNT TYPE SPACE
    DUP $ -2 = IF  DROP  MSG @ COUNT TYPE SPACE  ELSE  ." Error " .  THEN ;

: .args  argc . ." args: "  0 begin dup argc < while  dup argv type space  1+  repeat drop ;

: QUIT
    RP0 @ RP!  SOURCE-STACK 'IN !  \ 0 STATE !
    BEGIN  CR QUERY  ['] INTERPRET CATCH
        ?DUP IF .ERROR ELSE ." ok" THEN
    AGAIN ;



here ," Hello from Forth!" constant greeting

: hello  greeting count type cr ;

: run   sp@ sp0 !  rp@ rp0 !  hello  .args  cr words  QUIT  bye ;

t' run data-origin t!
here dp t!
LAST @ FORTH-WORDLIST T!


\ ============================================================
0 [if]
\ ============================================================


\ ============================================================
\ Interpreter ********** )


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
