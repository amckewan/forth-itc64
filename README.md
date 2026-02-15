# 64-bit Indirect-threaded Forth Model
This is an implementation of a 64-bit indirect-threaded Forth that runs
on x86-64 Linux.

It is a classic implementation similar to FIG-Forth and F83.
The assembly code is buit with `nasm`; the dictionary is cross-compiled
with `gforth`.

It currently passes the standard core test suite.

## Goals
The main goal is a simple, easy-to-
- Build a 64-bit Forth to run on an x86 Linux laptop.
- Use a simple model that is easy to understand and modify.
- Try an engine in assembly-language rather than C (back to basics).
- Separate code and data to make CPU porting straightforward.
- Implement OS interface with libc for portability.
- Don't deviate from the standard, pass at least the core test suite.
- Use memory efficiently, 64 bits doesn't meen you must use all 32 GB.

Non goals:

1. Performance
2. Full-featured (extensions, tools, docs, support, etc.)

## Summary

This implementation is similar to F83

My Forth roots start with F83 and this implementation uses a lot of that

The inner interpreter is a classic indirect-threaded implementation

The implementation is similar to F83 

## Memory Map
Memory is mapped at a fixed address with the `mmap()` function.
Linux and Windows allow you to map addresses as low as 64K, but
MacOS won't allocate below 4 GB. Given that, we map our Forth
dictionary at address $100000000 (4 GB).

The Forth dictionary is arranged as follows:
```
       limit -> +-------------------------------+ origin + memsize
                | input buffers                 |
         sp0 -> +-------------------------------+
                | stack, grows down             |
                |                               |
                |                               |
                |                               |
                | free space, grows up          |
        here -> +-------------------------------+
                |                               |
                | initial dictionary (data.bin) |
                |                               |
  data start -> +-------------------------------+ 1_0000_2000
                | x86-64 code (code.bin)        |
      origin -> +-------------------------------+ 1_0000_0000
```
We use the C stack as the Forth return stack.


## Registers
This is the register usage for x86 Linux.

| x86 | Forth | Notes
| --- | ----- | -----
| rax | top | Top of data stack
| rbx | w | XT of the currently executing word
| rcx | - | free
| rdx | - | free
| rsi | - | free
| rdi | - | free
| rsp | sp | Data-stack pointer
| rbp | rp | Return-stack pointer
| r8-11 | - | free
| r12 | ip | Instruction pointer
| r13 | lp | Local frame pointer
| r14 | up | User pointer (not currently used)
| r15 | origin | Start of dictionary

Unused registers may be freely used in code words.
All Forth registers except `rax` are preserved across
API calls (System V ABI).

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



, so we use the offset in cells 

to 64 bits so the low address bits are alwa

To reduce memory usage in colon defintions, we use 32-bit execution tokens.
A token is 


We can still address the full 64-bit 




### Word Headers

```
   | name (1-31) | count (1) | link (4) | code (8) | parameters (0+) |
```
\
\ The code and parameter fields are 8-byte aligned.
\ The link field is the xt of the previous definition or zero.


Developed on 64-bit Intel Ubuntu 24.04. A toy.

## Building
There are two areas of the dictionary, code and data.
The assembly code in 'kernel.asm' is built with NASM and produces two files:

`code.bin` - binary image to be loaded at origin

`code.sym` - symbols used to build the dictionary

The cross compiler `cross.fs` loads the code symbols and then
loads `kernel.f` to build the data dictionary which is written
to `data.bin`.
