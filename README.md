# 64-bit Indirect-threaded Forth Model

Developed on 64-bit Intel Ubuntu 24.04. A toy.

## Memory Map
Memory is mapped at a fixed address with the `mmap()` function.
Linux and Windows allow addresses as low as 64K, but documentation says
that MacOS won't allocate below 4 GB. Given that, we map our Forth
dictionary at address $100000000 (4 GB).

T

```
$1_XXXX_0000 | return stack, grows down     | <- rp0, rpb
$1_XXXX_0000 | input buffers                |
$1_XXXX_0000 | data stack, grows down       | <- sp0, rsp
             |                              |
             |                              |
             |                              |
$1_0000_1400 | start of data dictionary     |
$1_0000_1000 | system variables (1K)        |
$1_0000_0000 | x86 assembly code (4K)       | <- r15 (origin)
           0 | first 4 GB not used          |
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
