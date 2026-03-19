# 64-bit Indirect-Threaded Forth

This Forth model and implementation was inspired by
[this Linkedin post](https://www.linkedin.com/posts/activity-7413020788741521408-ywWR)
about the unique design of the 1980s video game Starflight
which was written in Forth. The author remarked that
"the interpreter is only 5% of the state: the rest is the Forth heap,
full of cons cells (basically) that function as both data and code."

This describes the classic Forth model I first learned
from public Forths like FIG-Forth and F83, and is the same model
as the first Win32Forth. Simple indirect-threaded code.
A small number of words are implemented in machine-dependent assembly code,
the rest of the dictionary is built as lists of pointers
to other words, the "cons cells."

The article concludes, that
"just as in the history of life, a lot of cool weird lineages died out."

We know Forth isn't quite dead yet, although it's not in the top 50
programming languages according to
[the TIOBE index](https://www.tiobe.com/tiobe-index).
There are viable Forth-based software companies,
hobby groups and, I am sure, many personal Forth projects.
This is one of them.

This is an adaptation of the classic Forth model to run on a modern
64-bit OS.
- 64-bit cell size and address space
- 32-bit execution tokens
- Forth addresses are process addresses (no rel>abs)
- Separate code and data
- 32 GB max dictionary size
- Indirect-threaded inner interpreter
- Kernel: 250 words, 3 KB code, 10 KB data
- Extended: 340 words, 15 KB data

Because we extended the cell size from 16 to 64 and the execution
token from 16 to 32 bits, we would expect Starflight to be about
twice the size of the DOS version
(assuming we had the source and the patience to port it).
We wouldn't need the
swapping code since the entire dictionary can fit in memory.
Perhaps it would fit on one
of those new-fangled 1.44 MB 3.5" floppies.

What is missing? A LOT! This is just enough
to compile itself and pass the standard core test suite.
I did this for fun.
If you want to program in Forth, consider a more complete system.
This is just a toy.

## Building
Building requires `make`, `clang`, `nasm` and `gforth`.

Try `make`, `make test` and `make run`.

| Source | Description |
| ------ | ----------- |
| fo.c | C wrapper that allocates memory, loads the dictionary, starts Forth and provides the BIOS
| bios.c | Implements basic OS functions
| cross.f | Forth cross-compiler
| kernel.f | Forth source for the kernel
| kernel.asm | x86-64 assembly source
| rth | Loads extensions on top of the kernel
| src/ | Forth source for the extensions
| test/ | Test suite
| bench/ | Benchmarks to compare with gforth (sanity check)

The wrapper `fo` is built from the C sources.

The assembly code in kernel.asm is built with NASM and produces two files:

`code.bin` - binary image to be loaded at origin

`code.sym` - symbols used to build the data dictionary

The cross compiler loads the code symbols and defines the words
that build the data dictionary.
We then load kernel.f to build the dictionary which is written
to `data.bin`.

With `fo`, `code.bin` and `data.bin`
we can then run Forth like this:

    $ ./fo rth

## Memory Map
Memory is mapped at a fixed address with the `mmap()` function.
Linux and Windows allow you to map addresses as low as 64K, but
MacOS won't allocate below 4 GB. Given that, we map our Forth
dictionary at address $100000000 (4 GB).

The Forth dictionary is arranged as follows:
```
      LIMIT --> +-------------------------------+
                |     input buffers (~4K)       |
      FIRST --> +-------------------------------+
                |    data stack, grows down     |
                |                               |
                |                               |
                |                               |
                |                               |
                |     free space, grows up      |
       HERE --> +-------------------------------+
                |                               |
                |          dictionary           |
                |                               |
                +-------------------------------+
                |           code (8K)           |
     ORIGIN --> +-------------------------------+
```
We use the C stack as the Forth return stack.

## x86 Registers
This is the register usage for x86 Linux:

| x86     | Forth   | Description
| ---     | -----   | -----
| `rax`   | `top`   | Top of data stack
| `rbx`   | `w`     | XT of the currently executing word
| `rcx`
| `rdx`
| `rsi`
| `rdi`
| `rsp`   | `sp`    | Data-stack pointer
| `rbp`   | `rp`    | Return-stack pointer
| `r8-11`
| `r12`   | `ip`    | Instruction pointer
| `r13`   | `lp`    | Local frame pointer
| `r14`   | `up`    | User pointer (not currently used)
| `r15`   | `origin` | Start of dictionary

Unassigned registers are freely used in code words.
All Forth registers except `rax` are preserved across API calls (System V ABI).

### Word Headers
Headers have the name preceeding the count so all fields are at a fixed offset
from the CFA. The CFA and PFA are cell-aligned.

| Field | Size | Abbr. | Description
| ----  | ---- | ----  | ----
| Name  | 1-31 |       | Name characters
| Count | 1    | NFA   | Count + flags
| Link  | 4    | LFA   | Link field, XT of previous definition
| Code  | 8    | CFA   | Code field, points to executable code
| Body  | 0+   | PFA   | Parameter field

## Inner Interpreter
Code fields are 8-byte aligned and contain the address of the
machine code implementing the word.

An execution token (XT) is the offset, in cells,
from the origin to the code field.
We limit the XT to 32 bits, giving us a maximum dictionary size of 32 GB.

    : XT  ( cfa -- xt )  ORIGIN -  3 RSHIFT ;
    : CFA ( xt -- cfa )  3 LSHIFT  ORIGIN + ;

The Forth instruction pointer (IP) is 4-byte aligned and points to the
XT of the next word to execute. The x86-64 implementation of NEXT is
three instructions:

        mov     ebx,[r12]       ; fetch xt (ebx zero extended -> rbx)
        add     r12,4           ; advance ip
        jmp     [r15+rbx*8]     ; indirect jump via code field

The code for a colon definition pushes the IP onto the return stack
and loads the IP from the PFA of the word. In x86-64 (simplified):

        mov     [rp-8],ip       ; push ip to the return stack
        sub     rp,8
        lea     ip,[r15+rbx*8+8] ; new ip = pfa
        next

At the end of a colon definition, we compile `;S` which does:

        mov     ip,[rp]         ; pop ip from the return stack
        add     rp,8
        next

## Porting
For x86 Windows, we would need to modify the OS interface to account
for the different x86-64 ABI.

x86 MacOS should be trivial (a recompile) although no longer meaningful.

ARM MacOS would require porting the assembly code to aarch64.
The Forth source and BIOS should not require changes.

Porting to a non-64-bit architecture is more significant since the code in
many places just assumes a 64 bit cell size.
