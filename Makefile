# Makefile for Forth ITC-64

FORTH = gforth
ASM = nasm
CC = clang

CFLAGS = -Wall -Werror
CFLAGS += -Os

SOURCES = src/fo.c src/bios.c
HEADERS = 
LIBS = -ledit
# LIBS += -ldl

FORTH_SOURCES := $(wildcard src/*.f)

all: forth

forth: fo code.bin data.bin

run: forth rth
	@./fo -v rth

test: forth rth $(FORTH_SOURCES)
	./fo -v rth test/all.f -e bye

fo: $(SOURCES) $(HEADERS)
	$(CC) $(CFLAGS) $(SOURCES) $(LIBS) -o $@

code.bin code.sym: src/kernel.asm
	$(ASM) -f bin -o code.bin -l code.lst $<
	@grep '^ *1' code.map | awk '{print "$$" $$2 " SYMBOL %" $$3}' > code.sym
	@rm code.map

data.bin: cross.f src/kernel.f code.sym
	$(FORTH) cross.f src/kernel.f -e done
	@hexdump -C data.bin > data.hex

clean:
	@rm -f fo *.o *.bin *.lst *.out *.map *.sym *.hex *~
