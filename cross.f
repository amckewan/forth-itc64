\ Cross compiler

[defined] empty [if] empty [then]
marker empty
only forth also definitions decimal

\ gforth
warnings off
\ w! exists
: w@ uw@ ;
: dw@ ul@ ;
: dw! l! ;

VOCABULARY HOST
VOCABULARY TARGET

ONLY FORTH ALSO HOST ALSO DEFINITIONS HEX

include code.sym

8 CONSTANT CELL

\ host words that will get redefined
: H.  . ;
: H,  , ;
: H:  : ;
: H;  POSTPONE ; ; IMMEDIATE

\ Memory Access Words
\ 0-4GB is reserved by the OS
\ $1_0000_0000 start of code area built by NASM (8K)
\ $1_0000_2000 start of the data dictionary (what we are building here)
%origin CONSTANT ORIGIN ( start of code dictionary on target)
ORIGIN 2000 + CONSTANT DATA-ORIGIN ( start of data dictionary on target)

CREATE IMAGE 4000 ALLOT   IMAGE 4000 ERASE
: THERE  ( taddr -- addr )   DATA-ORIGIN -  IMAGE + ;
: T@     ( taddr -- n )      THERE @ ;
: T!     ( n taddr -- )      THERE ! ;
: TC@    ( taddr -- char )   THERE C@ ;
: TC!    ( char taddr -- )   THERE C! ;
: TW@    ( taddr -- u16 )    THERE W@ ; 
: TW!    ( u16 taddr -- )    THERE W! ;
: TDW@   ( taddr -- u32 )    THERE DW@ ;
: TDW!   ( u32 taddr -- )    THERE DW! ;

VARIABLE H  DATA-ORIGIN H !
: HERE  ( -- taddr )   H @ ;
: ALLOT ( n -- )       H +! ;
: C,    ( char -- )    HERE TC!      1 H +! ;
: W,    ( u16 -- )     HERE TW!      2 H +! ;
: DW,   ( u32 -- )     HERE TDW!     4 H +! ;
: ,     ( n -- )       HERE T!    CELL H +! ;
: S,    ( addr len -- ) 
   0 ?DO   COUNT C,   LOOP   DROP ;

: ALIGN  BEGIN HERE 7 AND WHILE 0 C, REPEAT ;

: TDUMP  SWAP THERE SWAP DUMP ;

: IMAGE-SIZE ( -- n )  HERE DATA-ORIGIN - ;

\ save image
: ?ERR  ABORT" file I/O error" ;
: SAVE-IMG ( a n -- )
    R/W CREATE-FILE ?ERR >R
    IMAGE IMAGE-SIZE R@ WRITE-FILE ?ERR
    R> CLOSE-FILE ?ERR ;

: SAVE  ( -- )
    CR ." Saving " BASE @ DECIMAL IMAGE-SIZE . BASE ! ." bytes..."
    S" data.bin" SAVE-IMG ." done" ;

: ciao cr bye ;

\ **********************************************************************
\ Create target words
\
\   | name(1-31) | count(1) | link(4) | code(8) | parameters (0+) |
\
\ The code and parameter fields are 8-byte aligned.
\ The link field is a cell offset from origin, like an XT.

: xt ( cfa -- xt )  origin - 3 rshift ;

: prealign ( -- ) \ align so next word will have aligned cfa
    >in @  parse-name nip 1+  swap >in !
    begin  here over +  4 +  7 and while  0 c,  repeat drop ;

VARIABLE LAST \ target address of last link field
: HEADER   ( -- ) \ build name and link
    prealign  parse-name tuck s, c,
    here  last @ xt dw,  last ! ;

: prior ( -- nfa count )  last @ 1-  dup tc@ ;

: compile, ( xt -- )  dw, ;

VARIABLE STATE-T
: ?EXEC  STATE-T @ 0= ABORT" cannot execute target word!" ;

VARIABLE CSP
: !CSP  DEPTH CSP ! ;
: ?CSP  DEPTH CSP @ - ABORT" definition not finished" ;

: TCREATE ( -- )
    CREATE  HERE xt H,  DOES>  ?EXEC  @ COMPILE, ;
: TARGET-CREATE ( -- )
    >IN @ HEADER >IN !
    TARGET DEFINITIONS  TCREATE  HOST DEFINITIONS ;

: code ( ta -- )  target-create , ;

: T'  ' >BODY @ ;
\  : HAS ( n -- )  T' SWAP +ORIGIN T! ;

\ Target Literals
: LIT  ( n -- )  ?EXEC  [ %lit32 ] literal compile,  dw, ;
: $   BL WORD NUMBER DROP LIT ;
: [']  T' LIT ;

CODE NOT   %zero_equal ,

0 [if]

: LITERAL ( n -- )  ?EXEC  ['] LIT COMPILE,  DW, ;

CODE BRANCH    %branch ,
CODE 0BRANCH   %zero_branch ,

\ Target branching constructs
: ?CONDITION  INVERT ABORT" unbalanced" ;
: MARK      ( -- here )     ?EXEC  HERE  ;
: >MARK     ( -- f addr )   TRUE  MARK   0 C, ;
: >RESOLVE  ( f addr -- )   MARK  OVER -  SWAP TC!   ?CONDITION ;
: <MARK     ( -- f addr )   TRUE  MARK ;
: <RESOLVE  ( f addr -- )   MARK  - C,   ?CONDITION ;

: NOT  ?EXEC  70 C, ;

: IF        ['] 0BRANCH DW,  >MARK ;
: THEN      >RESOLVE ;
: ELSE      3 C,  >MARK  2SWAP >RESOLVE ;
: BEGIN     <MARK ;
: UNTIL     58 C,  <RESOLVE ;
: AGAIN     3 C,  <RESOLVE ;
: WHILE     IF  2SWAP ;
: REPEAT    AGAIN  THEN ;

: ?DO       4 C,  >MARK  <MARK ;
: DO        5 C,  >MARK  <MARK ;
: LOOP      6 C,  <RESOLVE  >RESOLVE ;
: +LOOP     7 C,  <RESOLVE  >RESOLVE ;

\ Compile Strings into the Target
: C"   HERE  [CHAR] " PARSE S, 0 C, ; \ c-style string
: ,"         [CHAR] " PARSE DUP C, S, ;

: S"      A C,  ," ;
: ."      B C,  ," ;
: ABORT"  C C,  ," ;

: { ;
: } ;
: forget ;
: ,A  , ;
: [COMPILE] ;
: 0, 0 , ;

\ : CELL+ CELL + ;
\ : CELLS CELL * ;

\ Defining Words
: CONSTANT  TARGET-CREATE  10 C, ALIGN   , ;
: VARIABLE  TARGET-CREATE  11 C, ALIGN 0 , ;

: BUFFER ( n <name> -- )  ALIGN  HERE  SWAP ALLOT  CONSTANT ;
: TAG  HERE  TAG DUP C, S,  CONSTANT ;

: [   0 STATE-T ! ;
: ]  -1 STATE-T ! ;

: T:  HEADER  ] ;  \ to create words with no host header

: ;_  POSTPONE ; ; IMMEDIATE
: IMMEDIATE  PRIOR 40 OR SWAP TC! ;
: ;   ?CSP EXIT [ ;
: :   TARGET-CREATE !CSP ] ;_

include ./kernel.f

DONE
SAVE
[then]
