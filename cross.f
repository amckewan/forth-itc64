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
: S,    ( a n -- )     0 ?DO  COUNT C,  LOOP  DROP ;

: ,"   [char] " parse dup c, s, ;

: ALIGN   BEGIN HERE 7 AND WHILE $ff C, REPEAT ;
: 4ALIGN  BEGIN HERE 3 AND WHILE $ff C, REPEAT ;

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
    begin  here over +  4 +  7 and while  $ff c,  repeat drop ;

VARIABLE LAST  \ xt of last target word
: HEADER   ( -- ) \ build name and link
    prealign  parse-name tuck s, c,
    last @ dw, ( link )  here xt last ! ;

: prior ( -- nfa count )  last @ 1-  dup tc@ ;

\ Compiler security
VARIABLE CSP
: !CSP   DEPTH CSP ! ;
: ?CSP   DEPTH CSP @ - ABORT" definition not finished" ;

VARIABLE STATE-T
: ?EXEC  STATE-T @ 0= ABORT" cannot execute target word" ;

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
: t:   target definitions  host  : ;
: t;   postpone ;  host definitions ; immediate

t: (   postpone ( t;
t: \   postpone \ t;

\ Mark and resolve target branches
: ?condition  invert abort" unbalanced" ;
: mark      ( -- here )     ?exec  here  ;
: >mark     ( -- f addr )   true  mark   0 dw, ;
: >resolve  ( f addr -- )   mark  over -  swap tdw!   ?condition ;
: <mark     ( -- f addr )   true  mark ;
: <resolve  ( f addr -- )   mark - dw,   ?condition ;

\  : constant ( n -- )  code  %doconstant ,  , ;
\  : create   ( -- )    code  %docreate , ;

\ Target compiler

\ Create, variable, and constant have host versions
: CREATE    >in @ code >in !  %docreate ,    here   constant ;
: CONSTANT  >in @ code >in !  %doconstant ,  dup ,  constant ;
: VARIABLE  create 0 , ;

t: [    state-t off  in-host  t;

: ]    state-t on  in-target ;
: :    code  %docolon ,  !csp  ] ;


\  include ./kernel.f
\  SAVE
