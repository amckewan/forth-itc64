( Search-order and vocabularies )

\ wordlist:   | last xt | voc-link | name flag |
VARIABLE VOC-LINK ( points to the most-recently-created wordlist )
: WORDLIST ( -- wid )
    ALIGN  HERE  0 , ( last xt )
    DUP VOC-LINK  DUP @ ,  ! ( link )
    FALSE , ( no name ) ;

: VOCABULARY ( -- ) \ named wordlist
    CREATE  WORDLIST  2 CELLS + ON ( has name )
    DOES>  CONTEXT ! ;

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

: .WID ( wid -- )
    DUP 2 CELLS + @ IF  [ 2 CELLS 5 + ] LITERAL - .NFA  ELSE  .  THEN ;

: ORDER ." Context: " GET-ORDER 0 ?DO  .WID  LOOP
        ." Current: " GET-CURRENT .WID ;

: VOCS  VOC-LINK BEGIN  @ ?DUP  WHILE  DUP .WID  CELL+  REPEAT ;

VOCABULARY FORTH
' FORTH >BODY CONSTANT FORTH-WORDLIST

CURRENT CELL+ @ ( head of current forth wordlist ) FORTH-WORDLIST !
ONLY FORTH ALSO DEFINITIONS
