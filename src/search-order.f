( Search-order and vocabularies )

\ wordlist:   | last xt | voc-link | nfa or 0 |
VARIABLE VOC-LINK ( points to the most-recently-created wordlist )
: WORDLIST ( -- wid )
    ALIGN  HERE  0 , ( last xt )
    DUP VOC-LINK  DUP @ ,  ! ( link )
    0 , ( no name ) ;

: VOCABULARY ( -- ) \ named wordlist
    CREATE  WORDLIST  LAST @  SWAP 2 CELLS + ! ( has a name )
    DOES>  CONTEXT ! ;

VOCABULARY FORTH
' FORTH >BODY CONSTANT FORTH-WORDLIST

: GET-ORDER ( -- widn ... wid1 n )
    0 ( n)  0 7 DO   I CELLS CONTEXT + @  ?DUP IF SWAP 1+ THEN  -1 +LOOP ;

: SET-ORDER ( widn ... wid1 n -- )
    CONTEXT 8 CELLS ERASE
    0 ?DO  I CELLS CONTEXT + !  LOOP ;

: GET-CURRENT   CURRENT @ ; ( ugh )
: SET-CURRENT   CURRENT ! ;
: DEFINITIONS   CONTEXT @  SET-CURRENT ;

: ONLY          0 SET-ORDER  FORTH ;
: ALSO          GET-ORDER  OVER SWAP 1+  SET-ORDER ;
: PREVIOUS      GET-ORDER  NIP       1-  SET-ORDER ;

: .WID ( wid -- )  DUP 2 CELLS + @ ?DUP IF  .NFA DROP  ELSE  .  THEN ;

: ORDER ." Context: " GET-ORDER 0 ?DO  .WID  LOOP
        ." Current: " GET-CURRENT .WID ;

: VOCS  VOC-LINK BEGIN  @ ?DUP  WHILE  DUP .WID  CELL+  REPEAT ;

CURRENT CELL+ @ ( head of current forth wordlist ) FORTH-WORDLIST !
ONLY FORTH ALSO DEFINITIONS
