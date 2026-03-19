# Bootstrapping

In the beginning there was F83: 16 bits, 8086, MS-DOS.

This begat Win32Forth: 32 bits, 80386, Windows.

This is the story of bootstrapping: 64 bits, x86-64, POSIX.

## Setup

I have an x86-64 Ubuntu laptop. I have gforth, clang, make, etc.
I have the source for a version of F83. Ironically, I don't have,
or at least couldn't find, the source for Win32Forth (and didn't
have the patience to extract it from the distributed exe).

I dug out an old 386 assembler I wrote with the intention of modifying
it for x86-64 (hence called x64) and using gforth to write a metacompiler.
I found a convenient [x64 instruction reference](https://www.felixcloutier.com/x86/).
This was the first time I'd looked at the x64 architecture and I was
surprised that it was more of a kludge on the 386 (which itself...) than
a new, clean design. At least it would make porting the assembler 
a reasonable project; many instructions have the same encoding,
just with a special prefix byte. But it would be a lot of work, time and risk,
and I wanted to start writing a Forth. I decided instead to use `nasm`,
an open-source x64 assembler that supports the familiar MASM syntax.

I didn't want to write the entire Forth in assembly language
like the original Win32Forth kernel. F83 tought me metacompiling and
there's no going back. This meant I would need to build the code
and data parts of the dictionary separately.

I kept the C wrapper to load and execute the image and provide a simple BIOS.
It has no knowledge of the Forth model other than two known entry points
at the start of the image (cold start and exception restart).

This led to a design with three build products:

| Name | Source | Tool | Product | Purpose
| -----| ----- | ------ | ----- | -------
| Loader | `fo.c` `bios.c` | clang | `fo` | Load and execute dictionary image, provide BIOS
| Code   | `kernel.asm`    | nasm | `code.bin` | Code primatives
| Data   | `kernel.f` | gforth | `data.bin` | Dictionary

## Getting Started
The first thing I did was to write some x64 assembly code with `nasm`.
I learned how to produce a flat binary file as well as a symbol table
that could be loaded in Forth.
This is where I experimented with the inner-interpreter design.
Nothing ran but I could see the output and learn the tools.

Actually, the very first thing I did was create repo in github and clone it.
I added a readme and license and pushed. Clean desk.

Then I started on the cross compiler. Not started as much as "clone and own"
the last cross compiler I wrote, which had evolved from the F83 meta-compiler.
I created some target headers and wrote the image to `data.bin`.

Next I wrote the wrapper (again starting from my last Forth) that
allocates memory and loads the two image files.

The build framework was now complete.

## Running Forth
I hand-wrote some threaded code in assembly and was able to call from C
to Forth and return. The first code did a `1+`.
```
one_plus_cfa:   dq      one_plus
exit_cfa:       dq      exitt

code quit
        dq      docolon
        dd      XT(one_plus_cfa)
        dd      XT(exit_cfa)
```
Then I did the same in Forth, using the code symbols prefixed with '%':
```
code 1+     %one_plus ,
code exit   %exitt ,

code run
    %docolon ,
    t' 1+ compile,
    t' exit compile,
```
We now have a running Forth system with all three parts.
Here is the simplified Makefile that builds the system:
```
fo: fo.c code.sym
	clang fo.c -o fo

code.bin code.sym: kernel.asm
	nasm -f bin -o code.bin kernel.asm
	grep '^ *1' code.map | awk '{print "$$" $$2 " CONSTANT %" $$3}' > code.sym

data.bin: cross.f kernel.f
	gforth cross.f -e "save cr bye"
```
And here we can see it run:
```
$ make fo
nasm -f bin -o code.bin kernel.asm
clang fo.c -o fo
gforth cross.f -e "save cr bye"

$ ./fo
origin: 0x100000000, memsize: 0x100000
loading code.bin at 0x100000000...read 9e0 bytes
loading data.bin at 0x100002000...read 50 bytes
running from 0x100000008 (mem=1 MB)
Forth returned 2
```

## Developing the Text Interpreter
I developed the interpreter in Forth, adding code words as needed.
I built and tested (by observation) in this order:

    TYPE            see something
    QUERY           get input from the user and show it
    WORD            break input into words
    NUMBER          convert words to numbers
    FIND            lookup words in the dictionary

And produced a working interpreter:
```
: INTERPRET  ( -- )
    BEGIN  BL WORD C@ WHILE
        HERE FIND IF EXECUTE ELSE NUMBER THEN
        DEPTH 0< IF ." stack empty " SP0 @ SP!  EXIT  THEN
    REPEAT ;

: QUIT
    SOURCE-STACK 'IN !
    BEGIN  CR QUERY  INTERPRET  ."  ok " AGAIN ;

HERE ," Hello from Forth!" CONSTANT GREETING

: HELLO  GREETING COUNT TYPE CR ;

: RUN   SP@ SP0 !  RP@ RP0 !  HELLO  QUIT  BYE ;
```
With these words:
```
RUN HELLO GREETING QUIT .args INTERPRET WORDS find2 FIND CURRENT CONTEXT
FORTH-WORDLIST SEARCH-WORDLIST MATCH comp2 COMP .NAME >NAME >BODY NFA LFA CFA
NUMBER NUM2 >NUMBER NUMBER? BASE DIGIT WORD HERE WBUF PARSE-NAME PARSE-WORD
PARSE ADVANCE SCAN SKIP QUERY REFILL REFILL-FILE REFILL-TIB SOURCE> >SOURCE
INIT-SOURCE SOURCE-DEPTH SOURCE-ID SOURCE SOURCE-STACK #SOURCE FNAME TIB LINE#
FID 'SOURCE >IN #TIB 'IN NEW-STRING FREE RESIZE ALLOCATE WRITE-LINE WRITE-FILE
READ-LINE READ-FILE CLOSE-FILE OPEN-FILE CREATE-FILE R/W W/O R/O .S DEPTH DUMP
. (.") SPACE CR BL ACCEPT TYPE EMIT KEY ARGV ARGC BYE BIOS 4ALIGNED ALIGNED
PLACE MOD */ OFF ON NOT FALSE TRUE 1 0 COMP CMOVE FILL /STRING COUNT CELL+
CELLS 2/ 2* 1- 1+ RSHIFT LSHIFT NEGATE INVERT 2OVER 2SWAP 2DROP 2DUP RP! RP@
SP! SP@ 2R@ 2R> 2>R R@ R> >R 2OVER 2SWAP 2DROP 2DUP PICK ?DUP NIP ROT OVER
SWAP DROP DUP NOT WITHIN U> U< > < = 0> 0< 0= 2! 2@ DW! DW@ W! W@ C! C@ +! ! @
XOR OR AND */MOD /MOD UM/MOD UM* / * - + (") LIT ?BRANCH BRANCH EXECUTE EXIT
;S RP0 SP0 'WARM 'COLD DP0 ORIGIN
```

## Finishing it off
Once I had a running interpreter it became much easier to add and test
incrementally.
I added defining words and changed the interpreter to observe STATE.
I started running the standard test suite to catch regressions.
I added and fixed until all the core tests passed.

After that it was mostly cleanup, refactoring, adding vocabularies, catch/throw,
exception handling, etc.

The last step was to produce a turnkey executable that has the dictionary
baked in rather than loading it at runtime.
