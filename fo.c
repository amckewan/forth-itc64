// fo.c

#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <sys/mman.h>

#define KB     * 1024ull
#define MB  KB * 1024
#define GB  MB * 1024

#define CODE_SIZE  8 KB     // first 8K of image for assembly code

const size_t ORIGIN = 4 GB;                     // start of forth dictionary
const size_t DATA_ORIGIN = ORIGIN + CODE_SIZE;  // start of data dictionary
const size_t MEMSIZE = 1 MB;                    // default without -m option

int verbose;

// ============================================================
// Allocate memory at a fixed address

void *allocate(size_t addr, size_t size) {
    return mmap((void *)addr, size, PROT_READ | PROT_WRITE, 
        MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED_NOREPLACE, -1, 0);
}

// ============================================================
// Load image

void load_bin(void *addr, const char *filename) {
    size_t maxsize = 1 GB;
    FILE *image = fopen(filename, "r");
    if (!image) {
        fprintf(stderr, "can't open image %s\n", filename);
        return;
    }
    printf("loading %s at %p...", filename, addr);
    size_t bytes = fread(addr, 1, maxsize, image);
    printf("read %lx bytes\n", bytes);
    fclose(image);
}

void load_image() {
    load_bin((void*)ORIGIN, "code.bin");
    load_bin((void*)DATA_ORIGIN, "data.bin");
}


// ============================================================
// Run Forth

typedef int (*cold_t)(int argc, char *argv[]);
#define COLD 0
#define WARM 1

int run(uint64_t *origin, int argc, char *argv[]) {
    cold_t cold = (cold_t) origin[COLD];
    return cold(argc, argv);
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

size_t getsize(const char *arg) {
    char *end;
    size_t size = strtoul(arg, &end, 10);
    switch (toupper(*end)) {
        case 'G':   size *= 1024;
        case 'M':   size *= 1024;
        case 'K':   size *= 1024;
    }
    size_t minsize = 0x10000; // 64K should do
    if (size < minsize) size = minsize;
    return size;
}

int main(int argc, char *argv[]) {
    size_t memsize = MEMSIZE;
    // char *image_file = 0;

    init_signals();

    // Process args, handle and remove the ones I use
    // Add the rest to fargc/fargv
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
                    memsize = getsize(arg);
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

    return 0;


    // if (image_file) {
    //     load_image(image_file, M, memsize);
    // } else {
    //     // use compiled-in dictionary image
    //     memcpy(M, dict, sizeof dict);
    // }

    // return run(fargc, fargv);
}
