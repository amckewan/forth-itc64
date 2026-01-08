\ ITC-64 Forth Kernel

0 , \ cold start xt

CODE EXIT       %exitt ,

CODE BRANCH     %branch ,
CODE ?BRANCH    %zero_branch ,

CODE LIT        %lit32 ,
CODE (")        %litq ,

CODE +          %plus ,
CODE -          %minus ,
CODE *          %star ,

CODE AND        %andd ,
CODE OR         %orr ,
CODE XOR        %xorr ,

CODE @          %fetch ,
CODE !          %store ,
CODE +!         %plus_store ,

CODE 0=         %zero_equal ,
CODE 0<         %zero_less ,
CODE 0>         %zero_greater ,
CODE =          %equal ,
CODE <          %less ,
CODE >          %greater ,
CODE U<         %uless ,
CODE U>         %ugreater ,

0 [if]


CODE DUP        *--S = top; NEXT
CODE DROP       pop; NEXT
CODE SWAP       w = top; top = *S; *S = w; NEXT
CODE OVER       push S[1]; NEXT
CODE ROT        w = S[1], S[1] = *S, *S = top, top = w; NEXT
CODE NIP        S++; NEXT
CODE ?DUP       if (top) *--S = top; NEXT
CODE PICK       top = S[top]; NEXT

CODE >R         *--R = top, pop; NEXT
CODE R>         push *R++; NEXT
CODE R@         push *R  ; NEXT

CODE R>DROP     ++R; NEXT
CODE DUP>R      *--R = top; NEXT

CODE 2>R        *--R = *S++, *--R = top, pop; NEXT
CODE 2R>        push R[1], push R[0], R += 2; NEXT
CODE 2R@        push R[1], push R[0]; NEXT

CODE I          push R[0] + R[1]; NEXT
CODE J          push R[3] + R[4]; NEXT
CODE LEAVE      I = (byte*)R[2];
CODE UNLOOP     R += 3; NEXT

CODE 2DUP       w = *S, *--S = top, *--S = w; NEXT
CODE 2DROP      top = S[1], S += 2; NEXT
CODE 2SWAP      w = S[0], S[0] = S[2], S[2] = w,
`               w = S[1], S[1] = top, top = w; NEXT
CODE 2OVER      w = S[2], *--S = top, *--S = w, top = S[3]; NEXT

CODE INVERT     top = ~top; NEXT
CODE NEGATE     top = -top; NEXT
CODE LSHIFT     top = *S++ << top; NEXT
CODE RSHIFT     top = ((ucell)*S++) >> top; NEXT

CODE MOD        top = *S++ % top;  NEXT
\ CODE UMOD       top = (ucell)*S++ % (ucell)top;  NEXT

` #define LOWER(u1,u2)  ((ucell)(u1) < (ucell)(u2))

CODE WITHIN
`   w = *S++,
`   top = LOWER(*S - w, top - w) LOGICAL;
`   S++;
`   NEXT

CODE M*  ( n1 n2 -- d ) {
`   i128 d = (i128)*S * (i128)top;
`   *S = d ;
`   top = d >> 64;
`   NEXT }

CODE UM* ( u1 u2 -- ud ) {
`   u128 u1 = (ucell)*S;
`   u128 u2 = (ucell)top;
`   u128 ud = u1 * u2;
`   *S = ud ;
`   top = ud >> 64;
`   NEXT }

CODE UM/MOD  ( ud u1 -- rem quot ) {
`   u128 ud = ((u128)*S << 64) | (u64)S[1];
`   u64 u = (u64)top;
`   u64 quot = ud / u;
`   u64 rem = ud % u;
`   *++S = rem;
`   top = quot;
`   NEXT }

CODE SM/REM  ( d n -- rem quot ) {
`   i128 d = ((i128)S[0] << 64) | (u64)S[1];
`   i128 quot = d / top;
`   i128 rem = d % top;
`   *++S = rem;
`   top = quot;
`   NEXT }

: 1+  $ 1 + ;
: 1-  $ 1 - ;
CODE 2*  top <<= 1; NEXT
CODE 2/  top >>= 1; NEXT

CELL CONSTANT CELL
: CELL+  CELL + ;

CODE COUNT  *--S = top + 1;
CODE C@     top = at8(top); NEXT
CODE C!     at8(top) = *S; pop2; NEXT

CODE 2@     *--S = at(top + CELL); top = at(top); NEXT
CODE 2!     at(top) = *S++; at(top + CELL) = *S++; pop; NEXT

( 16-bit fetch and store )
CODE W@     top = at16(top); NEXT
CODE W!     at16(top) = *S++, pop; NEXT

CODE FILL  ( a u c -- )       memset(ptr(S[1]), top, *S); pop3; NEXT
CODE MOVE  ( src dest u -- )  memmove(ptr(*S), ptr(S[1]), top); pop3; NEXT

CODE CMOVE ( src dest u -- )  w = *S++;
    ` while (top--) at8(w++) = at8((*S)++); pop2; NEXT

CODE CMOVE> ( src dest u -- )  w = *S++ + top;
    ` while (top--) at8(--w) = at8(*S + top); pop2; NEXT

CODE /STRING ( a u n -- a' u' ) S[1] += top, top = *S++ - top; NEXT

CODE COMPARE  top = compare(ptr(S[2]), S[1], ptr(*S), top); S += 3; NEXT
CODE SEARCH   top = search(S++, top); NEXT

( ********** Terminal I/O ********** )

CODE KEY    ( -- char )  push getchar(); NEXT
CODE EMIT   ( char -- )  putchar(top); pop; NEXT
CODE TYPE   ( a n -- )   type(*S, top); pop2; NEXT
CODE ACCEPT ( a n -- n ) top = accept(*S++, top); NEXT

: CR     $ 0A EMIT ;
: SPACE  $ 20 EMIT ;

( ********** System ********** )

CODE (BYE)  return top;
: BYE $ 0 (BYE) ;

CODE ARGC ( -- n ) push argc; NEXT
CODE ARGV ( n -- a n ) *--S = (cell)argv[top]; top = strlen(argv[top]); NEXT

CODE GETENV  ( name len -- value len )  top = get_env(S, top); NEXT
CODE SETENV  ( value len name len -- )  set_env(S, top); S += 3, pop; NEXT

( ********** Dynamic Libraries ********** )

CODE DLOPEN  ( name len -- handle )
    ` top = dl_open(*S++, top, RTLD_LAZY); NEXT
CODE DLCLOSE ( handle -- )
    ` dlclose((void *)top), pop; NEXT
CODE DLSYM ( name len handle -- sym )
    ` top = dl_sym(S[1], *S, top); S += 2; NEXT

CODE DLERROR ( -- addr len )
    ` w = (cell) dlerror(); if (w) push w, push strlen((char*)w);
    ` else push 0, push 0; NEXT

CODE DLCALL ( <args> #args sym -- result )
    ` w = dl_call(top, *S, S+1), S += *S + 1, top = w; NEXT

( ********** File I/O ********** )

C" r"  CONSTANT R/O
C" w"  CONSTANT W/O
C" w+" CONSTANT R/W

CODE CREATE-FILE ( c-addr u fam -- fileid ior )
    ` top = (cell)open_file(ptr(S[1]), *S, ptr(top));
    ` *++S = top, top = top ? 0 : -1; NEXT

CODE OPEN-FILE ( c-addr u fam -- fileid ior )
    ` top = (cell)open_file(ptr(S[1]), *S, ptr(top));
    ` *++S = top, top = top ? 0 : -1; NEXT

CODE CLOSE-FILE ( fileid -- ior )
    ` top = fclose((FILE*)top); NEXT

CODE READ-FILE ( a u fid -- u' ior )
    ` w = fread(ptr(S[1]), 1, *S, (FILE*)top);
    ` top = w == *S ? 0 : ferror((FILE*)top); *++S = w; NEXT

CODE READ-LINE ( a u fid -- u' flag ior )
    ` w = (cell)fgets(ptr(S[1]), *S + 1, (FILE*)top);
    ` if (!w) {
    `   top = feof((FILE*)top) ? 0 : ferror((FILE*)top);
    `   *S = S[1] = 0; NEXT
    ` }
    ` top = strlen((char*)w);
    ` if (top > 0 && ((char*)w)[top-1] == '\n') --top;
    ` S[1] = top, *S = TRUE, top = 0; NEXT

CODE WRITE-FILE ( a u fid -- ior )
    ` w = fwrite(ptr(S[1]), 1, *S, (FILE*)top);
    ` top = w == *S ? 0 : ferror((FILE*)top); S += 2; NEXT

CODE WRITE-LINE ( a u fid -- ior )
    ` w = fwrite(ptr(S[1]), 1, *S, (FILE*)top);
    ` if (w == *S) *S = 1, w = fwrite("\n", 1, 1, (FILE*)top);
    ` top = w == *S ? 0 : ferror((FILE*)top); S += 2; NEXT

( ********** Memory allocation ********** )

CODE ALLOCATE ( n -- a ior )    *--S = (cell) malloc(top), top = *S ? 0 : -1; NEXT
CODE RESIZE   ( a n -- a' ior ) *S = (cell) realloc(ptr(*S), top), top = *S ? 0 : -1; NEXT
CODE FREE     ( a -- ior )      if (top) free(ptr(top)); top = 0; NEXT

\ Allocate counted and null-terminate string
CODE NEW-STRING ( adr len -- c-str ) top = (cell)new_string(ptr(*S++), top); NEXT

( ********** Input source processig ********** )

8 CELLS CONSTANT #SOURCE ( size of each source entry )

\ 8 entries * 8 cells per entry
40 CELLS BUFFER SOURCE-STACK

: CELLS  CELL * ;

: >IN           'IN @ ;
: SOURCE-BUF    >IN $ 2 CELLS + ;
: SOURCE-FILE   >IN $ 3 CELLS + ;
: SOURCE-NAME   >IN $ 4 CELLS + ;
: SOURCE-LINE   >IN $ 5 CELLS + ;

: SOURCE        >IN CELL+ 2@ ;
: SOURCE-ID     SOURCE-FILE @ ;

: SOURCE-DEPTH  >IN SOURCE-STACK -  #SOURCE / ;

: FILE? ( source-id -- f )  1+ $ 1 U> ;

: >SOURCE ( filename len fileid | -1 -- )
    SOURCE-DEPTH $ 7 U> ABORT" nested too deep"
    #SOURCE 'IN +!
    DUP SOURCE-FILE !
    FILE? IF  $ 80 ALLOCATE DROP SOURCE-BUF !  NEW-STRING SOURCE-NAME !  THEN
    $ 0 SOURCE-LINE ! ;

: SOURCE> ( -- )
    SOURCE-DEPTH $ 1 < ABORT" trying to pop empty source"
    SOURCE-ID FILE? IF
        SOURCE-ID CLOSE-FILE DROP
        SOURCE-BUF  @ FREE DROP
        SOURCE-NAME @ FREE DROP
    THEN
    #SOURCE NEGATE 'IN +! ;

CODE REFILL ( -- f )  push refill(SOURCE); NEXT

\ ********** Numbers **********

` #define dot(n)  printf(BASE == 16 ? "%tx " : "%td ", n)

CODE .  ( n -- )  dot(top), pop; NEXT

CODE DIGIT ( ch -- n )  top = digit(top); NEXT

CODE -NUMBER  ( a -- a t, n f ) w = number(ptr(top), --S, BASE);
`   if (w) top = 0; else *S = top, top = -1; NEXT
: NUMBER  ( a -- n )  -NUMBER ABORT" ? " ;

CODE >NUMBER  top = to_number(S, top, BASE); NEXT

\ ********** Parsing **********

20 CONSTANT BL

CODE PARSE    ( c -- a n )  top = parse(SOURCE, top, --S); NEXT
CODE PARSE-NAME ( -- a n )  push parse_name(SOURCE, --S); NEXT

CODE WORD  ( char -- addr )
`   top = word(SOURCE, top, HERE); NEXT

\ ********** Dictionary search **********

CODE SEARCH-WORDLIST  ( c-addr u wid -- 0 | xt 1 | xt -1 )
    ` w = search_wordlist(S[1], S[0], top);
    ` if (w > 0) *++S = w, top = -1;
    ` else if (w < 0) *++S = -w, top = 1;
    ` else S += 2, top = 0; NEXT

CODE FIND  ( str -- xt flag | str 0 )
    ` w = find(top, ORIGIN + CELLS(CONTEXT));
    ` if (w > 0) *--S = w, top = -1;
    ` else if (w < 0) *--S = -w, top = 1;
    ` else push 0; NEXT

: '  ( --- xt )  BL WORD FIND 0= ABORT" ?" ;

CODE >NAME ( xt -- nfa )  top = xt_to_name(top); NEXT
CODE NAME> ( nfa -- xt )  top = name_to_xt(top); NEXT

CODE DEPTH ( -- n )  w = S0 - S; push w; NEXT
CODE .S ( -- )
    ` w = S0 - S; if (w <= 0) { printf("empty "); NEXT }
    ` S[-1] = top;
    ` for (w -= 2; w >= -1; w--) dot(S[w]);
    ` NEXT

CODE WORDS  ( -- )  words(M[CONTEXT]); NEXT
CODE DUMP  ( a n -- )  dump(*S++, top, BASE); pop; NEXT
CODE VERBOSE  push (cell)&verbose; NEXT

( ********** Catch/Throw ********** )

CODE EXECUTE ( xt -- )  *--R = (cell)I, I = (u8*)top, pop; NEXT

CODE CATCH  ( xt -- ex# | 0 )
    ` CATCH, *--R = (cell) &RESUME, I = (u8*)top, pop; NEXT

CODE THROW  ( n -- )
    ` if (!top) pop; else if (!HANDLER) goto abort; else THROW; NEXT

CODE RESET  R = R0, HANDLER = 0; NEXT
 
( ********** Compiler ********** )

VARIABLE dA ( offset for target compiler )
VARIABLE ?CODE 0 ,

: -OPT  $ 0 ?CODE ! ;

CODE UNUSED  ( -- u )  push (cell)R0 - CELLS(256) - HERE; NEXT

: HERE   H @  ;
: ALLOT  H +! ;
: ,   HERE !  CELL H +! ;
: C,  HERE C!  $ 1 H +! ;
: W,  HERE W!  $ 2 H +! ;
: H,  HERE  !  $ 4 H +! ;

CODE ALIGNED  top = aligned(top); NEXT
: ALIGN  BEGIN HERE CELL 1- AND WHILE $ 0 C, REPEAT ;

: OP, ( opc -- )  ?CODE @ HERE ?CODE 2!  C, ;

: LITERAL  $ 20 OP, , ; IMMEDIATE

: LATEST ( -- op | 0 )  ?CODE @ DUP IF C@ THEN ;
: PATCH  ( op -- )      ?CODE @ C! ;
: REMOVE ( -- )         $ 0 ?CODE 2@  H !  ?CODE 2! ;

: LIT?  ( -- f )  ?CODE @ DUP IF  C@ $ 20 =  THEN ;
: LIT@  ( -- n )  ?CODE @ $ 1 + @ ;
: LIT!  ( n -- )  ?CODE @ $ 1 + ! ;

: BINARY ( op -- ) \ e.g. lit +
    LIT? IF  LIT@ REMOVE
        LIT? IF  LIT@ SWAP ROT ( n1 n2 op )
            HERE !  HERE EXECUTE  LIT!
        ELSE
            SWAP $ 40 XOR OP, ,
        THEN
    ELSE  OP,
    THEN ;

: MEMORY  ( op -- ) \ e.g lit @
    LIT? IF  $ 40 XOR PATCH  ELSE  OP,  THEN ;

: NOT,  ( op -- )  \ invert last conditional op
    LATEST  DUP $ 70 $ 80 WITHIN  OVER $ F7 AND $ 33 $ 38 WITHIN OR
    IF  $ 8 XOR PATCH DROP  ELSE  DROP OP,  THEN ;

: PACK ( opc -- ) \ peephole optimizer
    DUP $ 60 $ 80 WITHIN
    IF  DUP $ 68 $ 6B WITHIN IF  MEMORY EXIT  THEN
        DUP $ 70 =           IF  NOT,   EXIT  THEN
        BINARY EXIT
    THEN OP, ;

: LITOP ( xt -- )
    COUNT  SWAP @ [COMPILE] LITERAL  $ 40 XOR PACK ;

: INLINE?  ( xt -- n t | f ) \ count ops >= $60
    DUP BEGIN  DUP C@ WHILE
        COUNT $ 60 < IF  2DROP $ 0 EXIT  THEN
    REPEAT SWAP - $ -1 ;

: INLINE ( xt n -- ) $ 0 ?DO  COUNT PACK  LOOP DROP ;

: COMPILE,  ( xt -- )
    \ inline primatives
    DUP INLINE? IF INLINE EXIT THEN

    \ inline constant etc.
    DUP C@ $ 10 = IF ( constant ) CELL+ @      [COMPILE] LITERAL  EXIT THEN
    DUP C@ $ 11 = IF ( variable ) CELL+ dA @ - [COMPILE] LITERAL  EXIT THEN
    DUP C@ $ 13 = IF ( value )    CELL+ dA @ - $ 28 OP, ,         EXIT THEN

    \ inline lit op exit (e.g. 1+, HERE)
    DUP COUNT $ 20 $ 40 WITHIN  SWAP CELL+ C@ 0= AND IF  LITOP EXIT  THEN

\ Optional check for bad behavior!
\    DUP CELL 1- AND ABORT" xt not aligned"

    \ compile short call in first 64k cells
    DUP $ 10000 CELLS U< IF  $ 1 OP, dA @ - CELL / W,  EXIT THEN

    \ default to far call
    $ 2 OP, dA @ - , ;

( optimize tail calls )
: EXIT  LATEST $ 1 = IF  $ 9 PATCH  ELSE  $ 0 OP,  THEN ; IMMEDIATE

( ********** Interpreter ********** )

: ?STACK  DEPTH 0< ABORT" stack?" ;

: INTERPRET  ( -- )
    BEGIN  BL WORD  DUP C@ WHILE
        FIND ?DUP IF
            STATE @ = IF  COMPILE,  ELSE  EXECUTE  ?STACK  THEN
        ELSE
            NUMBER  STATE @ IF  [COMPILE] LITERAL  THEN
        THEN
    REPEAT DROP ;

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

: (INCLUDE)  BEGIN REFILL WHILE INTERPRET REPEAT ;

: INCLUDE-FILE  ( str len fid -- )  >SOURCE  HANDLER @
    IF  ['] (INCLUDE) CATCH SOURCE> THROW  ELSE  (INCLUDE) SOURCE>  THEN ;

: INCLUDED  ( str len -- )
    2DUP R/O OPEN-FILE ABORT" file not found" INCLUDE-FILE ;

: INCLUDE  PARSE-NAME INCLUDED ;

80 BUFFER TIB
: QUERY  $ 0 SOURCE-FILE !  TIB SOURCE-BUF !  REFILL 0= IF BYE THEN ;

: QUIT  RESET  $ 0 STATE !
    BEGIN  SOURCE-DEPTH WHILE  SOURCE>  REPEAT
    BEGIN  CR QUERY  INTERPRET  STATE @ 0= IF ."  ok" THEN  AGAIN ;
1 HAS QUIT

TAG TAG

: COLD
    SOURCE-STACK 'IN !
    ARGC $ 1 ?DO  I ARGV INCLUDED  LOOP
    TAG COUNT TYPE  QUIT ;
0 HAS COLD

( ********** Defining Words ********** )

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
    BEGIN  DUP 1+ HERE +  DUP ALIGNED - WHILE  $ 0 C,  REPEAT ( align lfa )
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
: VARIABLE  CREATE  $ 0 , ;

\ | opc | I for does | data
: DOES>   R> dA @ -  $ 8 LSHIFT $ 12 OR  LAST CELL+ @ ! ;
: >BODY   CELL+ ;

\ Be careful from here on...

: [  $ 0 STATE ! ; IMMEDIATE
T: ;  [COMPILE] EXIT [COMPILE] [ REVEAL ; IMMEDIATE forget
: RECURSE  LAST CELL+ @ COMPILE, ; IMMEDIATE

: ]  $ -1 STATE ! ;
: :NONAME  ALIGN HERE  DUP $ 0 LAST 2!  -OPT  ] ;
: :  HEADER HIDE ] ;

``
default:
    printf("Invalid opcode 0x%02X\n", I[-1]);
    top = -256;
    goto abort;
}
``
[then]
