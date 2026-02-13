# 64-bit Indirect-threaded Forth Model

This is an implementation of Forth with the following goals:

0. Build a 64-bit Forth to run on my Linux laptop.
1. Use a simple model that is easy to understand and modify.
2. Try an engine in assembly-language rather than C.
3. Separate code and data making porting straightforward.
3. Don't deviate from the standard, pass at least the core test suite.
4. Use memory efficiently, 64 bits doesn't meen you must use all 32 GB.

Non goals:

1. Performance
2. Full-featured (extensions, tools, docs, support, etc.)

## Summary




Developed on 64-bit Intel Ubuntu 24.04. A toy.

## Memory Map
Memory is mapped at a fixed address with the `mmap()` function.
Linux and Windows allow you to map addresses as low as 64K, but
MacOS won't allocate below 4 GB. Given that, we map our Forth
dictionary at address $100000000 (4 GB).

We use the C stack as our return stack (rpb). The Forth dicationary
is arranged as follows:
```
   limit     -> +-------------------------------+ origin + memsize
                | input buffers                 |
   sp0 (rsp) -> +-------------------------------+
                | stack, grows down             |
                |                               |
                |                               |
                |                               |
                | free space, grows up          |
   here (dp) -> +-------------------------------+
                |                               |
                | initial dictionary (kernel.f) |
                |                               |
                +-------------------------------+ 1_0000_2000
                | x86-64 code (kernel.asm)      |
origin (r15) -> +-------------------------------+ 1_0000_0000

```
## Registers

| x86 | Forth | Notes
| --- | ----- | -----
| rax | top | Top of data stack
| rbx | word | XT of the currently executing word
| rcx | -
| rdx | -
| rsi | -
| rdi | -
| rsp | sp | Data stack pointer
| rbp | rp | Return stack pointer
| r8-11 | -
| r12 | ip | Instruction pointer
| r13 | lp | Locals frame pointer
| r14 | up | User pointer (not currently used)
| r15 | origin | Points to start of dictionary

Unused registers may be freely used in code words.
All Forth registers except `rax` are preserved across
API calls (System V ABI).

## Building
There are two areas of the dictionary, code and data.
The assembly code in 'kernel.asm' is built with NASM and produces two files:

`code.bin` - binary image to be loaded at origin

`code.sym` - symbols used to build the dictionary

The cross compiler `cross.fs` loads the code symbols and then
loads `kernel.f` to build the data dictionary which is written
to `data.bin`.
