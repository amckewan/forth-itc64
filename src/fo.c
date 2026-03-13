// C wrapper for Forth

#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <setjmp.h>
#include <sys/mman.h>

#define KB     * 1024ul
#define MB  KB * 1024
#define GB  MB * 1024

typedef  int64_t i64;
typedef uint64_t u64;
typedef  uint8_t u8;

// ORIGIN and CODE_SIZE defined on the command line
u64 const CODE_START = ORIGIN;
u64 const DATA_START = ORIGIN + CODE_SIZE;

u64 const MAX_SIZE = 32 GB;        // max dictionary size by design
u64 const DEFAULT_SIZE = 1 MB;     // default without -m option

int verbose; // for debugging

// ============================================================
// System variables at origin shared between C and Forth.

u64 * const sysvar = (u64 *) ORIGIN;

#define COLD 0      // cold start entry, cold()
#define WARM 1      // warm start after signal, warm()

// ============================================================
// Run Forth. Call sysvar[COLD] as if it were a C function.
// See kernel.asm

typedef i64* (*bios_t)(i64 svc, i64 *sp);
typedef void (*cold_t)(int argc, char *argv[], u64 memsize, bios_t bios);
typedef void (*warm_t)(int sig);

i64 *bios(i64 svc, i64 *sp); // in bios.c

void cold(int argc, char *argv[], u64 memsize) {
    cold_t cold = (cold_t) sysvar[COLD];
    if (verbose) printf("Cold start from %p\n", cold);
    cold(argc, argv, memsize, bios);
}

void warm(int sig) {
    warm_t warm = (warm_t) sysvar[WARM];
    if (verbose) printf("Warm start from %p (sig=%d)\n", warm, sig);
    warm(sig);
}

// ============================================================
// Allocate memory at a fixed address

void *allocate(u64 addr, u64 size) {
    return mmap((void *)addr, size, PROT_READ | PROT_WRITE | PROT_EXEC, 
        MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED_NOREPLACE, -1, 0);
}

// ============================================================
// Load image

#ifdef TURNKEY

// For turnkey executable, compile images as static data.
int load_image() {
    static u8 code_image[] = {
        #include "../code.inc"   
    };
    static u8 data_image[] = {
        #include "../data.inc"
    };

    memcpy((void*)CODE_START, code_image, sizeof code_image);
    memcpy((void*)DATA_START, data_image, sizeof data_image);

    return 1;
}

#else

// Not TURNKEY, read image from files at runtime.
// Hard coded to load code.bin and data.bin separately

int load_bin(void *addr, u64 size, const char *filename) {
    FILE *image = fopen(filename, "r");
    if (!image) {
        fprintf(stderr, "can't open image %s\n", filename);
        return 0;
    }
    u64 bytes = fread(addr, 1, size, image);
    if (verbose) printf("read %ld bytes from %s to %p\n",
        bytes, filename, addr);
    fclose(image);
    return 1;
}

int load_image() {
    return load_bin((void*)CODE_START, CODE_SIZE, "code.bin") && 
           load_bin((void*)DATA_START, DEFAULT_SIZE, "data.bin");
}

#endif // TURNKEY

// ============================================================
// Catch signals

static sigjmp_buf jmpbuf;

const char *signal_name(int signum) {
    switch (signum) {
        case SIGSEGV:   return "SIGSEGV";
        case SIGBUS:    return "SIGBUS";
        case SIGFPE:    return "SIGFPE";
        case SIGINT:    return "SIGINT";
    }
    return "UNKNOWN";
}

void signal_handler(int signum, siginfo_t *signinfo, void *ctx) {
    ucontext_t *context = (ucontext_t *)ctx;
    u64 pc = context->uc_mcontext.gregs[16];
    u64 ip = context->uc_mcontext.gregs[4];
    fprintf(stderr, "\nCaught signal %d (%s), PC=%lX, IP=%lx\n",
            signum, signal_name(signum), pc, ip);
    siglongjmp(jmpbuf, signum);
    exit(EXIT_FAILURE); // Terminate the program
}

void init_signals() {
    struct sigaction sa;
    sa.sa_flags = SA_SIGINFO;
    sa.sa_sigaction = signal_handler;
    sigemptyset(&sa.sa_mask);

    sigaction(SIGSEGV, &sa, 0);
    sigaction(SIGBUS,  &sa, 0);
    sigaction(SIGFPE,  &sa, 0);
    sigaction(SIGINT,  &sa, 0);
}

// ============================================================
// Main

u64 get_memsize(const char *arg) {
    char *end;
    u64 size = strtoul(arg, &end, 10);
    switch (toupper(*end)) {
        case 'G':   size *= 1024;
        case 'M':   size *= 1024;
        case 'K':   size *= 1024;
    }
    u64 minsize = 0x10000; // 64K should do
    if (size < minsize) size = minsize;
    return size;
}

int main(int argc, char *argv[]) {
    u64 memsize = DEFAULT_SIZE;
    // char *image_file = 0;

    init_signals();

    // Process args, handle and remove the ones I use here.
    // Add the rest to fargc/fargv and give to Forth.
    int fargc = 1;
    char **fargv = calloc(argc, sizeof *argv);
    fargv[0] = argv[0];
    for (int i = 1; i < argc; i++) {
        char *arg = argv[i];
        if (*arg++ == '-') {
            switch (*arg) {
                case 'm':
                    if (!*++arg && ++i < argc)
                        arg = argv[i];
                    memsize = get_memsize(arg);
                    continue;
                case 'v':
                    verbose = strlen(arg);
                    continue;
                // case 'i':
                //     if (++i < argc) image_file = argv[i];
                //     continue;
            }
        }
        // add forth arg as a null-terminated string
        fargv[fargc++] = argv[i];
    }

    // Allocate memory for the dictionary
    void *origin = allocate(ORIGIN, memsize);
    if (origin == MAP_FAILED) {
        fprintf(stderr, "mmap failed address=%zx, size=%lX\n", ORIGIN, memsize);
        return 1;
    }
    if (verbose) printf("origin: %p, memsize: 0x%lx\n", origin, memsize);

    if (!load_image()) {
        fprintf(stderr, "failed to load image at address=%zx, size=%lX\n", ORIGIN, memsize);
        return 2;
    }

    // Run forth with signal handling
    int sig = sigsetjmp(jmpbuf, 1);
    if (sig == 0) {
        cold(fargc, fargv, memsize);
    } else {
        warm(sig);
    }

    return 0;
}
