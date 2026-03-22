// Forth BIOS

#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <editline/history.h>

typedef  int64_t i64;
typedef uint64_t u64;

extern int verbose;

static const char* const modes[] = {"r", "w", "r+", "w+"};

static FILE *open_file(const char *str, int len, int fam) {
    const char*mode = modes[fam];
    char *filename = malloc(len + 1);
    memcpy(filename, str, len);
    filename[len] = 0;
    FILE *file = fopen(filename, mode);
    free(filename);
    return file;
}

i64 accept(void *buf, i64 max) {
    char *line = readline(0);

    if (!line) return -1; // EOF or error

    int len = strlen(line);
    if (len && line[len-1] == '\n') len--;
    if (len > max) len = max;
    memcpy(buf, line, len);

    // undo newline echoed by readine
    // move cursor to the end of the previous line and erase to the end
    // \033[1A      up 1 line
    // \033[%dC     move to end
    // \033[K       erase to end of line (then add space)
    printf("\033[1A\033[%dC\033[K ", len); fflush(stdout);

    add_history(line);
    free(line);
    return len;
}

void dump(unsigned char *addr, u64 len) {
    for (u64 i = 0; i < len; i += 16, addr += 16) {
        printf("\n%04lX: ", (u64)addr);
        for (int j = 0; j < 16; j++) {
            if (j % 4 == 0) putchar(' ');
            printf("%02X ", addr[j]);
        }
        putchar(' ');
        for (int j = 0; j < 16; j++) {
            putchar(isprint(addr[j]) ? addr[j] : '.');
        }
    }
}

i64 *bios(i64 svc, i64 *sp) {
    FILE *file;
    i64 n;
    char *s;

    switch (svc) {
    case 0x00:  // BYE ( n -- )
                if (verbose) printf("\nBIOS: exit %ld\n", sp[0]);
                exit(sp[0]); // ciao...
    case 0x01:  // KEY ( -- char )
                *--sp = getchar();
                break;
    case 0x02:  // EMIT ( char -- )
                putchar(*sp++);
                break;
    case 0x03:  // TYPE ( a n -- )
                //printf("\nBIOS: type 0x%lx len=%ld\n", sp[1], sp[0]);
                fwrite((void*)sp[1], 1, sp[0], stdout);
                sp += 2;
                break;
    case 0x04:  // ACCEPT ( a n -- n )
                sp[1] = accept((void*)sp[1], sp[0]);
                sp++;
                break;
    case 0x05:  // . ( n signed -- ) \ for bringup
                printf(sp[0] ? "%ld" : "%lX", sp[1]);
                sp+=2;
                break;
    case 0x06:  // dump ( a n -- )
                dump((void*)sp[1], sp[0]);
                sp += 2;
                break;
    case 0x10:  // OPEN-FILE ( c-addr u fam -- fileid ior )
                file = open_file((char*)sp[2], sp[1], sp[0]);
                sp += 1;
                sp[1] = (i64) file;
                sp[0] = file ? 0 : -1;
                break;
    case 0x11:  // CLOSE-FILE ( fileid -- ior )
                file = (FILE*) sp[0];
                sp[0] = fclose(file);
                break;
    case 0x12:  // READ-FILE ( a u fid -- u' ior )
                file = (FILE*) sp[0];
                n = fread((void*)sp[2], 1, sp[1], file);
                sp[2] = n;
                sp[1] = (n == sp[1]) ? 0 : ferror(file);
                sp += 1;
                break;
    case 0x13:  // READ-LINE ( a n fid -- #read flag ior )
                file = (FILE*) sp[0];
                // read one more byte to allow for newline (std)
                s = fgets((void*)sp[2], sp[1]+1, file);
                if (s != 0) {
                    n = strlen(s);
                    if (n && s[n-1] == '\n') --n;
                    sp[0] = 0;
                    sp[1] = -1;
                    sp[2] = n;
                } else {
                    sp[0] = feof(file) ? 0 : ferror(file);
                    sp[1] = 0;
                    sp[2] = 0;
                }
                break;
    case 0x14:  // WRITE-FILE ( a u fid -- ior )
                file = (FILE*) sp[0];
                n = fwrite((void*)sp[2], 1, sp[1], file);
                sp[2] = (n == sp[1]) ? 0 : ferror(file);
                sp += 2;
                break;
    case 0x15:  // WRITE-LINE ( a u fid -- ior )
                file = (FILE*) sp[0];
                n = fwrite((void*)sp[2], 1, sp[1], file);
                if (n == sp[1]) {
                    sp[1] = 1;
                    n = fwrite("\n", 1, 1, file);
                }
                sp[2] = (n == sp[1]) ? 0 : ferror(file);
                sp += 2;
                break;
    case 0x16:  // std-fid ( fd -- stdin | stdout | stderr )
                // 0=stdin, 1=stout, 2=stderr
                if (*sp == 0) *sp = (i64) stdin;  else
                if (*sp == 1) *sp = (i64) stdout; else
                if (*sp == 2) *sp = (i64) stderr; else *sp = 0;
                break;
    case 0x20:  // ALLOCATE ( n -- a ior )
                n = (i64) malloc(sp[0]);
                --sp;
                sp[1] = n;
                sp[0] = n ? 0 : -1; 
                break;                    
    case 0x21:  // FREE     ( a -- ior )
                free((void*)sp[0]);
                sp[0] = 0;
                break;
    case 0x22:  // RESIZE   ( a n -- a' ior )
                n = sp[1] = (i64) realloc((void*)sp[1], sp[0]);
                sp[0] = n ? 0 : -1; 
                break;

    }
    return sp;
}

