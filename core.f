
: (         ')' PARSE   2DROP ; IMMEDIATE
: \         SOURCE >IN ! DROP ; IMMEDIATE

: DECIMAL   #10 BASE ! ; DECIMAL
: HEX       #16 BASE ! ;

: [         STATE OFF ; IMMEDIATE

: [COMPILE] ' COMPILE, ; IMMEDIATE

: VARIABLE  CREATE  0 , ;

: S,        HERE SWAP  DUP ALLOT  CMOVE ;
: ,"        '"' PARSE  DUP C,  S,  4ALIGN ;
\  : SLITERAL  $A C, DUP C, S, -OPT ; IMMEDIATE
\ : S"        $A C, ," ; IMMEDIATE
\  : ."        $B C, ," ; IMMEDIATE
\  : ABORT"    $C C, ," ; IMMEDIATE

: ABORT     -1 THROW ;

( Control structures )
: >MARK     HERE 0 DW, ;
: >RESOLVE  HERE OVER -  SWAP DW! ;
: <MARK     HERE ;
: <RESOLVE  HERE - DW, ;

: IF        COMPILE ?BRANCH  >MARK ; IMMEDIATE
: THEN      >RESOLVE ; IMMEDIATE
: ELSE      COMPILE BRANCH  >MARK  SWAP >RESOLVE ; IMMEDIATE

: BEGIN     <MARK ; IMMEDIATE
: AGAIN     COMPILE  BRANCH  <RESOLVE ; IMMEDIATE
: UNTIL     COMPILE ?BRANCH  <RESOLVE ; IMMEDIATE
: WHILE     [COMPILE] IF  SWAP ; IMMEDIATE
: REPEAT    [COMPILE] AGAIN  [COMPILE] THEN ; IMMEDIATE

: DO        COMPILE (DO)     >MARK     <MARK    ; IMMEDIATE
: ?DO       COMPILE (?DO)    >MARK     <MARK    ; IMMEDIATE
: LOOP      COMPILE (LOOP)   <RESOLVE  >RESOLVE ; IMMEDIATE
: +LOOP     COMPILE (+LOOP)  <RESOLVE  >RESOLVE ; IMMEDIATE

: LITERAL   COMPILE LIT  , ; IMMEDIATE \ todo: optimize for lit32

: CHAR      BL WORD 1+ C@ ;
: [CHAR]    CHAR [COMPILE] LITERAL ; IMMEDIATE
: [']       ' [COMPILE] LITERAL ; IMMEDIATE

: ABS       DUP 0< IF NEGATE THEN ;
: MIN       2DUP > IF SWAP THEN DROP ;
: MAX       2DUP < IF SWAP THEN DROP ;
: S>D       DUP 0< ;

: */        */MOD NIP ;

: SPACES    0 MAX  0 ?DO  SPACE  LOOP ;

: POSTPONE  BL WORD FIND  DUP 0= ABORT" ?"
    0< IF  [COMPILE] LITERAL  ['] COMPILE,  THEN  COMPILE, ; IMMEDIATE

: EVALUATE ( a n -- )
    -1 >SOURCE  >IN CELL+ 2!  0 >IN !  HANDLER @
    IF  ['] INTERPRET CATCH SOURCE> THROW  ELSE  INTERPRET SOURCE>  THEN ;

\ Interpreter string literals
\ Standard says minimum 2 * 80 char buffers
CREATE SBUF 2 80 * ALLOT
VARIABLE SBUF#
: 'SBUF ( -- a )  SBUF# @ DUP 1 XOR SBUF# !  80 * SBUF + ;
: STASH ( a n -- a' n )
    DUP>R 80 U> ABORT" too big for stash"
    'SBUF SWAP OVER R@ MOVE R> ;

\ state-smart version
: S"  [CHAR] " PARSE
      STATE @ IF  [COMPILE] SLITERAL  ELSE  STASH  THEN ; IMMEDIATE

\ Pictured numeric output
\ Adapted from Wil Baden's ThisForth
VARIABLE HLD
: PAD       HERE 200 + ;
: <#        PAD HLD ! ;
: HOLD      HLD @ 1 -  DUP HLD !  C! ;
: HOLDS     BEGIN DUP WHILE 1- 2DUP + C@ HOLD REPEAT 2DROP ;
: SIGN      0< IF [CHAR] - HOLD THEN ;
: >char     dup 10 < not if [ 10 'A' - '0' + ] literal - then '0' + ;
: #         0 BASE @ UM/MOD >R BASE @ UM/MOD SWAP >char HOLD R> ;
: #S        BEGIN   #   2DUP OR 0 = UNTIL ;
: #>        2DROP  HLD @  PAD OVER - ;
: (.)       dup >r  abs  0 <# #s r> sign #> ;
: .         (.) TYPE   SPACE ;
: .R        >R (.) R> OVER - SPACES TYPE ;
: U.        0 <# #S #> TYPE   SPACE ;
: U.R       >R 0 <# #S #> R> OVER - SPACES  TYPE ;
: H.        BASE @ HEX  SWAP U.  BASE ! ;
: ?         @ . ;
