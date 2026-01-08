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

WORDLIST CONSTANT HOST-WORDLIST
WORDLIST CONSTANT TARGET-WORDLIST

: >CONTEXT ( wid -- )  >R GET-ORDER NIP  R> SWAP SET-ORDER ;

: HOST     HOST-WORDLIST   >CONTEXT ;
: TARGET   TARGET-WORDLIST >CONTEXT ;

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

: ALIGN   BEGIN HERE 7 AND WHILE 0 C, REPEAT ;
: ALIGN4  BEGIN HERE 3 AND WHILE 0 C, REPEAT ;

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

VARIABLE LAST  \ xt of last target word
: HEADER   ( -- ) \ build name and link
    prealign  parse-name tuck s, c,
    last @ dw, ( link )  here xt last ! ;

: prior ( -- nfa count )  last @ 1-  dup tc@ ;

VARIABLE STATE-T
: ?EXEC  STATE-T @ 0= ABORT" cannot execute target word!" ;

: TARGET-WORD ( -- ) \ create target word that compiles itself
    CREATE  HERE XT H,  DOES>  ?EXEC  @ DW, ;
: CODE ( -- )  >IN @  HEADER  >IN !
    TARGET-WORDLIST SET-CURRENT  TARGET-WORD  HOST-WORDLIST SET-CURRENT ;

: IN-HOST    ONLY FORTH ALSO HOST ALSO ;
: IN-TARGET  ONLY TARGET ;

: TFIND ( a n -- xt )
    TARGET-WORDLIST SEARCH-WORDLIST  0= ABORT" TARGET word not found" ;

: T' ( -- xt )  PARSE-NAME TFIND >BODY @ ;

: [TARGET]  PARSE-NAME TFIND COMPILE, ; IMMEDIATE

\ Create TARGET compiler words (like normal immediate words)
: t:   target-wordlist set-current  : ;
: t;   postpone ;  host-wordlist set-current ; immediate

: constant ( n -- )  code  %doconstant ,  , ;
: create   ( -- )    code  %docreate , ;
: variable ( -- )    create 0 , ;

\ Target branching constructs
: ?condition  invert abort" unbalanced" ;
: mark      ( -- here )     ?exec  here  ;
: >mark     ( -- f addr )   true  mark   0 dw, ;
: >resolve  ( f addr -- )   mark  over -  swap tdw!   ?condition ;
: <mark     ( -- f addr )   true  mark ;
: <resolve  ( f addr -- )   mark - dw,   ?condition ;

\ Strings
: ,"   [char] " parse dup c, s, ;
\ Target compiler
variable csp
: !csp   depth csp ! ;
: ?csp   depth csp @ - abort" definition not finished" ;

t: [    state-t off  in-host  t;

: ]    state-t on  in-target ;
: :    code  %docolon ,  !csp  ] ;

\ ================= TEST ===============

0 , \ cold start xt

CODE EXIT   %unnest ,
t: ;  ?csp  [target] exit  [target] [  t;

CODE LIT  %lit32 ,
t: literal ( n -- )  ?exec  [target] lit  dw,  t;
t: $  bl word number drop  [target] literal  t;

CODE BRANCH     %branch ,
CODE ?BRANCH    %branch_if_zero ,
t: if        [target] ?BRANCH  >mark  t;
t: then      >resolve  t;
t: else      [target] BRANCH  >mark  2swap >resolve  t;
t: begin     <mark  t;
t: until     [target] ?BRANCH  <resolve  t;
t: again     [target] BRANCH   <resolve  t;
t: while     [target] if  2swap  t;
t: repeat    [target] again  [target] then  t;

CODE 1+     %one_plus ,
CODE +      %plus ,
CODE DUP    %dupp ,
CODE =      %equal ,
CODE <      %less ,

CODE (")   %litq ,
t: "   [target] (")  ,"  align4  t;

5 constant mino

: RUN1  $ 100 + ;
: RUN  BEGIN DUP mino < WHILE 1+ REPEAT ;

\  code run ( memsize argv argc -- n )
\      %docolon ,
\      T] 1+ 1+ 1+ exit T[
\      \  t' 1+ compile,
\      \  t' 1+ compile,
\      \  t' 1+ compile,
\      t' exit compile,

t' run data-origin t!

\  : HAS ( n -- )  T' SWAP +ORIGIN T! ;

\ Target Literals
\  : LIT  ( n -- )  ?EXEC  [ %lit32 ] literal compile,  dw, ;
\  : $   BL WORD NUMBER DROP LIT ;
\  : [']  T' LIT ;

\ CODE NOT   %zero_equal ,


0 [if]

: LITERAL ( n -- )  ?EXEC  ['] LIT COMPILE,  DW, ;

CODE BRANCH    %branch ,
CODE ?BRANCH   %zero_branch ,


: NOT  ?EXEC  70 C, ;


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
