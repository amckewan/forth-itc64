\ Cross compiler

only forth also definitions decimal
warnings off

[UNDEFINED] DW@ [IF]
\ gforth
\ w! exists
: w@ uw@ ;
: dw@ ul@ ;
: dw! l! ;
\ my number
: number ( adr len -- n )  here place  here number drop ;
[THEN]

\ host words that will get redefined
\  : H.  . ;
: H,  , ;
\  : H:  : ;
\  : H;  POSTPONE ; ; IMMEDIATE

\ Host & target vocabularies
WORDLIST CONSTANT HOST-WORDLIST         \ cross compiler
WORDLIST CONSTANT TARGET-WORDLIST       \ target words

: >CONTEXT ( wid -- )  >R GET-ORDER NIP  R> SWAP SET-ORDER ;

: HOST     HOST-WORDLIST   >CONTEXT ;
: TARGET   TARGET-WORDLIST >CONTEXT ;

: IN-HOST    ONLY FORTH ALSO HOST ALSO ;
: IN-TARGET  ONLY TARGET ;

IN-HOST DEFINITIONS HEX

\ Include target code symbols
: symbol  constant ;

include code.sym

2000 CONSTANT CODE-SIZE     ( memory reserved for code )

\ Memory Access Words
\ 0-4GB is reserved by the OS
\ $1_0000_0000 start of code area built by NASM (8K)
\ $1_0000_2000 start of the data dictionary (what we are building here)
%origin CONSTANT ORIGIN ( start of code dictionary on target)
ORIGIN CODE-SIZE + CONSTANT DATA-ORIGIN ( start of data dictionary on target)

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
: ,     ( n -- )       HERE T!       8 H +! ;
: S,    ( a n -- )     0 ?DO  COUNT C,  LOOP  DROP ;

: ,"   [char] " parse dup c, s, ;

( fill with $FF to make it more visible in dump )
: ALIGN     BEGIN HERE 7 AND WHILE $FF C, REPEAT ;
: XT-ALIGN  BEGIN HERE 3 AND WHILE $FF C, REPEAT ;

: TDUMP  SWAP THERE SWAP DUMP ;

: IMAGE-SIZE ( -- n )  HERE DATA-ORIGIN - ;

\ save image
: ?ERR  ABORT" file I/O error" ;
: SAVE-IMG ( a n -- )
    R/W CREATE-FILE ?ERR >R
    IMAGE IMAGE-SIZE R@ WRITE-FILE ?ERR
    R> CLOSE-FILE ?ERR ;

variable #words
variable #code
: SAVE  ( -- )  base @ decimal
    cr ." Target words: " #words ? 
    cr ." Code words: " #code  ?
    cr ." Code size: " [ %code_end %origin - ] literal .
    cr ." Data size: " image-size .
    cr ." Saving " S" data.bin" 2dup type SAVE-IMG
    base ! ;

: done  save cr bye ;

\ **********************************************************************
\ Create target words
\
\   | name(1-31) | count(1) | link(4) | code(8) | parameters (0+) |
\
\ The code and parameter fields are 8-byte aligned.
\ The link field is a cell offset from origin, like an XT.

: xt  ( cfa -- xt )  origin - 3 rshift ;
: cfa ( xt -- cfa )  3 lshift origin + ;

: prealign ( -- ) \ align so next word will have aligned cfa
    >in @  parse-name nip 1+  swap >in !
    begin  here over +  4 +  7 and while  $ff c,  repeat drop ;

VARIABLE LATEST  \ xt of last target word
: HEADER   ( -- ) \ build name and link
    prealign  parse-name tuck s, c,
    latest @ dw, ( link )  here xt latest ! ;


: prior ( -- nfa count )  latest @ 1-  dup tc@ ;

\ Compiler security
VARIABLE CSP
: !CSP   DEPTH CSP ! ;
: ?CSP   DEPTH CSP @ - ABORT" definition not finished" ;

VARIABLE STATE-T
: ?EXEC  STATE-T @ 0= ABORT" cannot execute target word" ;

: (TCREATE) ( -- ) \ create target word that compiles itself
    CREATE  HERE XT H,  DOES>  ?EXEC  @ DW, ;
: TCREATE ( -- )  >IN @  HEADER  >IN !
    TARGET DEFINITIONS  (TCREATE)  HOST DEFINITIONS   1 #WORDS +! ;

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

\ Target compiler
: immediate  latest @ cfa 5 - ( nfa )  dup tc@  $80 or  swap tc! ;

\ Create, variable, and constant have host versions
: recreate  >in @  tcreate  >in !  ;
: CREATE    recreate  %docreate ,  0 , ( for dodoes )   here constant ;
: VARIABLE  recreate  %dovariable ,  here  0 ,  constant ;
: CONSTANT  recreate  %doconstant ,  dup ,  constant ;

: CODE   tcreate  1 #code +! ;

t: [    state-t off  in-host  t;

: ]    state-t on  in-target ;
: :    tcreate  %docolon ,  !csp  ] ;
