# 64-bit Indirect-Threaded Forth

This Forth model and implementation was inspired by
[this Linkedin post](https://www.linkedin.com/posts/activity-7413020788741521408-ywWR)
by Daniel Colascione about the unique design of the 1980s video game
Starflight which was written in Forth. Daniel remarked,
"the interpreter is only 5% of the state: the rest is the Forth heap, full of cons cells (basically) that function as both data and code."

The interpreter 5% refers to the machine code for the indirect-threaded Forth.
I thought it would be interesting to implement this model for an x86-64 Linux.

## Summary
The model supports a dictionary of up to 32 GB. The stack is 64-bits wide.
An execution token (a Forth "instruction") is 32 bits, defined as an offset,
in 64-bit cells, from the start of the dictionary (thus the 32 GB limit).

This is a classic Forth model similar to F83 (but without blocks),
from where I also borrowed the implementation of some code words.
The assembly code is built with `nasm`; the dictionary is cross-compiled
with `gforth` or by itself.

The source code consists of:
- `fo.c` is a C wrapper that allocates memory, loads the dictionary,
starts Forth and provides the BIOS.
- `bios.c` implements the BIOS which has some basic OS functions.
- `cross.f` is the source for the cross-compiler.
- `kernel.f` is the Forth source for the kernel (built with cross.f).
- `kernel.asm` is the x86-64 assembly source.
- The `src` directory contains the rest of the Forth system that is loaded
on top of the kernel.

| Statistics | |
| --- | --- |
| Kernel words | 237 |
| Code words | 97 |
| Code size | 3,440 |
| Data size | 10,704 |

It currently passes the standard core test suite.

## Memory Map
Memory is mapped at a fixed address with the `mmap()` function.
Linux and Windows allow you to map addresses as low as 64K, but
MacOS won't allocate below 4 GB. Given that, we map our Forth
dictionary at address $100000000 (4 GB).
The maximum size of the dictionary is 32 GB.

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

## Inner Interpreter
Code fields are 8-byte aligned. We define an execution token (XT)
as the offset, in cells, from the origin to the code field.
A 32-bit XT gives us a maximum dictionary size of 32 GB.

    : XT  ( cfa -- xt )  ORIGIN -  3 RSHIFT ;
    : CFA ( xt -- cfa )  3 LSHIFT  ORIGIN + ;

The Forth instruction pointer (IP) is 4-byte aligned and points to the
XT of the next word to execute. The x86-64 implementation of NEXT is
three instructions:

    418B1C24   mov ebx,[r12]     ; fetch 32-bit XT to rbx (zero extended)
    4983C404   add r12,4         ; increment IP
    41FF24DF   jmp [r15+rbx*8]   ; indirect jump through the cfa

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

## Building
There are two areas of the dictionary, code and data.
The assembly code in 'kernel.asm' is built with NASM and produces two files:

`code.bin` - binary image to be loaded at origin

`code.sym` - symbols used to build the dictionary

The cross compiler `cross.fs` loads the code symbols and then
loads `kernel.f` to build the data dictionary which is written
to `data.bin`.

## Porting
For x86-64 Windows, we would need to modify the OS interface to account
for the different x86-64 ABI.

x86-64 MacOS should be trivial (a recompile) although no longer meaningful.

aarch MacOS would require porting the assembly code to aarch64.
The Forth source and BIOS should not require changes.

Porting to a non-64-bit architecture is more significant since the code in
many places just assumes a 64 bit cell size.
