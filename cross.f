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

: TAG S" cross" ;

HEX

CREATE EOL 1 C, 0A C,
: H, , ;

8 CONSTANT CELL

\ Memory Access Words
\ 0-4GB is reserved by the OS
\ $1_0000_0000 start of code area built by NASM (8K)
\ $1_0000_2000 start of the data dictionary (what we are building here)
100000000 CONSTANT CODE-ORIGIN ( start of code dictionary on target)
100002000 CONSTANT DATA-ORIGIN ( start of data dictionary on target)

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
: prealign ( -- ) \ align so next word will have aligned cfa
    >in @  parse-name nip 1+  swap >in !
    begin  here over +  4 +  7 and while  0 c,  repeat drop ;

VARIABLE LAST \ target address of last code field
: HEADER   ( -- ) \ build name and link
    prealign
    parse-name tuck s, c,
    last @ 3 rshift dw,
    here last ! ;

header 1
header 22
header 333
header 4444
header 55555
save

0 [if]
\ header
\ name-chars (1-n) | len+flags (1) | link (4) | code (4) | pfa (aligned)

: name, ( a n -- ) \ name string, from parse area or ?, not HERE!
    begin  dup 1+ here +  dup aligned - while  0 c,  repeat
    tuck s, c, ;

variable last-lfa
: link,  here  last-lfa @ cell / 32,  last-lfa ! ;

: header2  parse-name name,  link,  $efbeadde 32, ;

: header >in @ header2 >in ! header ;

: PRIOR ( -- nfa count )  LAST @ CELL +  DUP TC@ ;

VARIABLE STATE-T
: ?EXEC  STATE-T @ 0= ABORT" cannot execute target word!" ;

VARIABLE CSP
: !CSP  DEPTH CSP ! ;
: ?CSP  DEPTH CSP @ - ABORT" definition not finished" ;

: TARGET-CREATE   ( -- )
   >IN @ HEADER >IN !  CREATE  HERE H,
   DOES>  ?EXEC  @ COMPILE, ;

: H.  . ;
: T'  ' >BODY @ ;
: HAS ( n -- )  T' SWAP +ORIGIN T! ;

\ Generate primatives
: ?COMMENT  ( allow Forth comment after OP: etc. )
    >IN @  BL WORD COUNT S" (" COMPARE
    IF  >IN !  ELSE  DROP  [COMPILE] (  THEN ;

: C-COMMENT  S" /* " WRITE  BL WORD COUNT WRITE  S"  */ " WRITE ;
VARIABLE OP  ( next opcode )
: OP!  OP ! ;
: OP:  ( output opcode case statement )
    OP @ FF > ABORT" opcodes exhausted"
    OP @ info
    C-COMMENT  S" case 0x" WRITE  OP @ 0 <# # # #> WRITE  S" : " WRITE
    ?COMMENT ` ( copy rest of line )  1 OP +! ;
: ---  1 OP +! ;

: CODE   >IN @ TARGET-CREATE >IN !  OP @ C,  EXIT  OP: ;

\ Target Literals
: LITERAL  ( n -- )  ?EXEC  20 C,  , ;
: $   BL WORD NUMBER DROP LITERAL ;
: [']  T' LITERAL ;

\ Target branching constructs
: ?CONDITION  INVERT ABORT" unbalanced" ;
: MARK      ( -- here )     ?EXEC  HERE  ;
: >MARK     ( -- f addr )   TRUE  MARK   0 C, ;
: >RESOLVE  ( f addr -- )   MARK  OVER -  SWAP TC!   ?CONDITION ;
: <MARK     ( -- f addr )   TRUE  MARK ;
: <RESOLVE  ( f addr -- )   MARK  - C,   ?CONDITION ;

: NOT  ?EXEC  70 C, ;

: IF        58 C,  >MARK ;
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
