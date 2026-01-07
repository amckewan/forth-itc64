# 64-bit Indirect-threaded Forth Model

Developed on 64-bit Intel Ubuntu 24.04. A toy.

## Memory Map
Memory is mapped at a fixed address with the `mmap()` function.
Linux and Windows allow addresses as low as 64K, but documentation says
that MacOS won't allocate below 4 GB. Given that, we map our Forth
dictionary at address $100000000 (4 GB).

T

```
X_XXXX_XXXX | return stack, grows down     | <- rp0
             |                              |
             | input buffers                |
X_XXXX_XXXX | data stack, grows down       | <- sp0
             |                              |
             |                              |
             |                              | <- here
             |                              |
1_0000_2000 | start of data dictionary     |
1_0000_0100 | x86 assembly code            |
1_0000_0000 | system variables             | <- origin (r15)


   rp0 (rbp) -> +-------------------------------+
                | return stack, grows down      |
                +-------------------------------+
                | input buffers                 |
   sp0 (rsp) -> +-------------------------------+
                | stack, grows down             |
                |                               |
                |                               |
                | free space, grows up          |
   here (dp) -> +-------------------------------+
                | initial dictionary (kernel.f) |
                +-------------------------------+ 1_0000_2000
                | prebuilt code (kernel.asm)    |
                +-------------------------------+ 1_0000_0100
                | system variables (kernel.asm) |
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
| r14 | up | User pointer (not used)
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