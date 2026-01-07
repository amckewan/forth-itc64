// fo.c

#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <sys/mman.h>

#define KB     * 1024ul
#define MB  KB * 1024
#define GB  MB * 1024

#define CODE_SIZE  8 KB     // first 8K of image for x86 machine code

uint64_t const ORIGIN = 4 GB;           // start of forth dictionary

uint64_t const CODE_START = ORIGIN;     // start of code
uint64_t const DATA_START = CODE_START + CODE_SIZE; // initial dp

uint64_t const MAX_SIZE = 32 GB;        // max dictionary size by design
uint64_t const DEFAULT_SIZE = 1 MB;     // default without -m option

int verbose;

// ============================================================
// System variables at origin shared between C and Forth.

uint64_t * const sysvar = (uint64_t *) ORIGIN;

#define COLD 0

// ============================================================
// Run Forth. Call CODE_START as if it were a C main function.
// See kernel.asm

typedef int (*cold_start_t)(int argc, char *argv[]);

int run(int argc, char *argv[]) {
    cold_start_t cold = (cold_start_t) sysvar[COLD];
    printf("running from %p\n", cold);
    return cold(argc, argv);
}

// ============================================================
// Allocate memory at a fixed address

void *allocate(uint64_t addr, uint64_t size) {
    return mmap((void *)addr, size, PROT_READ | PROT_WRITE | PROT_EXEC, 
        MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED_NOREPLACE, -1, 0);
}

// ============================================================
// Load image

void load_bin(void *addr, const char *filename) {
    uint64_t maxsize = DEFAULT_SIZE; // temp
    FILE *image = fopen(filename, "r");
    if (!image) {
        fprintf(stderr, "can't open image %s\n", filename);
        return;
    }
    printf("loading %s at %p...", filename, addr);
    uint64_t bytes = fread(addr, 1, maxsize, image);
    printf("read %lx bytes\n", bytes);
    fclose(image);
}

void load_image() {
    load_bin((void*)CODE_START, "code.bin");
    // load_bin((void*)DATA_START, "data.bin");
}

// ============================================================
// Catch signals

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
    uint64_t ip = context->uc_mcontext.gregs[16];
    fprintf(stderr, "\nCaught signal %d (%s) RIP=%lX\n",
            signum, signal_name(signum), ip);
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

uint64_t get_memsize(const char *arg) {
    char *end;
    uint64_t size = strtoul(arg, &end, 10);
    switch (toupper(*end)) {
        case 'G':   size *= 1024;
        case 'M':   size *= 1024;
        case 'K':   size *= 1024;
    }
    uint64_t minsize = 0x10000; // 64K should do
    if (size < minsize) size = minsize;
    return size;
}

int main(int argc, char *argv[]) {
    uint64_t memsize = DEFAULT_SIZE;
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
        fargv[fargc++] = argv[i];
    }

    // Allocate memory for the dictionary
    void *origin = allocate(ORIGIN, memsize);
    if (origin == MAP_FAILED) {
        fprintf(stderr, "mmap failed address=%zx, size=%lX\n", ORIGIN, memsize);
        return 1;
    }
    printf("origin: %p, memsize: 0x%lx\n", origin, memsize);

    load_image();

    int rc = run(fargc, fargv);

    printf("Forth returned %d\n", rc);

    return 0;


    // if (image_file) {
    //     load_image(image_file, M, memsize);
    // } else {
    //     // use compiled-in dictionary image
    //     memcpy(M, dict, sizeof dict);
    // }

    // return run(fargc, fargv);
}
