// fo.c

#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <sys/mman.h>

const size_t ORIGIN = (4ull*1024*1024*1024);  // start of forth dictionary
#define DATASIZE    (1*1024*1024)       // 1MB memory size without -m option

int verbose;

void *reserve(size_t addr, size_t size) {
    return mmap((void *)addr, size, PROT_READ | PROT_WRITE, 
        MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED_NOREPLACE, -1, 0);
}

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
    size_t datasize = DATASIZE;
    char *image_file = 0;

    // init_signals();

    // process args, handle and remove the ones I use
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
                    datasize = getsize(arg);
                    continue;
                case 'v':
                    verbose = strlen(arg);
                    continue;
                case 'i':
                    if (++i < argc) image_file = argv[i];
                    continue;
            }
        }
        fargv[fargc++] = argv[i];
    }

    // Allocate memory for dictionary
    void *membase = reserve(ORIGIN, datasize);
    if (membase == MAP_FAILED) {
        fprintf(stderr, "mmap failed address=%zx, size=%lX\n", ORIGIN, datasize);
        return 1;
    }
    printf("membase: %p, origin: 0x%zx, datasize: 0x%lx\n", membase, ORIGIN, datasize);


    return 0;


    // if (image_file) {
    //     load_image(image_file, M, datasize);
    // } else {
    //     // use compiled-in dictionary image
    //     memcpy(M, dict, sizeof dict);
    // }

    // return run(fargc, fargv);
}

#if 0

// Run the Forth VM
int run(int argc, char *argv[]) {
    return 0;
}

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
    u64 ip = context->uc_mcontext.gregs[16];
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

// Load image
void load_image(const char *filename, void *addr, int size) {
    printf("load image %s at %p\n", filename, addr);
    FILE *image = fopen(filename, "r");
    if (!image) {
        fprintf(stderr, "can't open image %s\n", filename);
        return;
    }
    fread(addr, 1, size, image);
    fclose(image);
}

int main(int argc, char *argv[]) {
    cell datasize = DATASIZE;
    char *image_file = 0;

    init_signals();

    // process args, handle and remove the ones I use
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
                    datasize = getsize(arg);
                    continue;
                case 'v':
                    verbose = strlen(arg);
                    continue;
                case 'i':
                    if (++i < argc) image_file = argv[i];
                    continue;
            }
        }
        fargv[fargc++] = argv[i];
    }

    // Map in memory at 64K
    void *membase = reserve(ORIGIN, datasize);
    if (membase == MAP_FAILED) {
        fprintf(stderr, "mmap failed address=%x, size=%lX\n", ORIGIN, datasize);
        return 1;
    }
    //printf("membase: %p, origin: 0x%x, datasize: 0x%lx\n", membase, ORIGIN, datasize);

    R0 = (cell*) (ORIGIN + datasize);

    if (image_file) {
        load_image(image_file, M, datasize);
    } else {
        // use compiled-in dictionary image
        memcpy(M, dict, sizeof dict);
    }

    return run(fargc, fargv);
}
#endif
