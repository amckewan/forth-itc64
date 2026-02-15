# Makefile

ASM = nasm
CC = clang
CFLAGS = -Wall -Werror
CFLAGS += -Ofast

SOURCES = fo.c bios.c
HEADERS = 
LIBS = -ledit -ldl

FORTH_SOURCES := $(wildcard src/*.f)

all: forth

forth: fo code.bin data.bin

run: forth rth
	@./fo -v rth

test: forth rth
	./fo -v rth test/suite.f -e bye

fo: $(SOURCES) $(HEADERS)
	$(CC) $(CFLAGS) $(SOURCES) $(LIBS) -o $@

code.bin code.sym: kernel.asm
	$(ASM) -f bin -o code.bin -l code.lst $<
	@grep '^ *1' code.map | awk '{print "$$" $$2 " SYMBOL %" $$3}' > code.sym
	@rm code.map

data.bin: cross.f kernel.f code.sym
	gforth cross.f kernel.f -e "save cr bye"
	@hexdump -C data.bin > data.hex

clean:
	@rm -f fo *.o *.bin *.lst *.out *.map *.sym *.hex *~
