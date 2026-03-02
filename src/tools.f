( programming tools & misc. )

( comment to end of file )
: \S  BEGIN REFILL 0= UNTIL ;

( Multi-line comments )
: COMMENT  CHAR
    BEGIN  DUP DUP PARSE + C@ = NOT
    WHILE  REFILL NOT ABORT" comment?"
    REPEAT DROP ;

comment * this is a test *
comment *
this is also a test*
comment ~
this
is
typical
~

( Adapted from the standard. )
: [ELSE] ( -- )
    1 BEGIN
        BEGIN BL WORD COUNT WHILE
          DUP " [IF] " ICOMP 0= IF
            DROP 1+
          ELSE
            DUP " [ELSE] " ICOMP 0= IF
              DROP 1- DUP IF 1+ THEN
            ELSE
              " [THEN] " ICOMP 0= IF
                1-
              THEN
            THEN
          THEN ?DUP 0= IF EXIT THEN
        REPEAT DROP
    REFILL 0= UNTIL  DROP ; IMMEDIATE

: [IF]  0= IF  [COMPILE] [ELSE]  THEN ; IMMEDIATE
: [THEN] ; IMMEDIATE

: [DEFINED]    DEFINED NIP 0= NOT ; IMMEDIATE
: [UNDEFINED]  DEFINED NIP 0=     ; IMMEDIATE

\ My needs are simpler than require, e.g.
\ need locals from opt/locals.f
\ need off : off 0 swap ! ;
: need  defined nip if [COMPILE] \ then ;
: from  include ; ( sugar )
