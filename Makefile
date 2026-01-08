# Makefile

ASM = nasm
CC = clang
CFLAGS = -Wall -Werror
CFLAGS += -Ofast

SOURCES = fo.c
HEADERS = 
#LIBS = -ledit -ldl
LIBS =

all: fo code.bin data.bin

fo: $(SOURCES) code.sym
	$(CC) -DKERNEL $(CFLAGS) $(SOURCES) $(LIBS) -o $@

code.bin code.sym: kernel.asm
	$(ASM) -f bin -o code.bin -l code.lst $<
	@grep '^ *1' code.map | awk '{print "$$" $$2 " CONSTANT %" $$3}' > code.sym

data.bin: cross.f kernel.f code.sym
	gforth cross.f kernel.f -e "save cr bye"

clean:
	@rm -f fo *.o *.bin *.lst *.out *.map *.sym *~
