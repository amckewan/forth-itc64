# Makefile for Forth ITC-64

all: forth

# Dictionary address and code size (data size set at runtime)
ORIGIN := 0x100000000
CODE_SIZE := 0x2000
CODE_SIZE_FORTH := HEX 2000 DECIMAL

# Build tools
FORTH = gforth
ASM = nasm
CC = clang

# Build flags
AFLAGS = -dORIGIN=$(ORIGIN) -dCODE_SIZE=$(CODE_SIZE)
AFLAGS += -f bin

CFLAGS = -DORIGIN=$(ORIGIN) -DCODE_SIZE=$(CODE_SIZE)
CFLAGS += -Wall -Werror
CFLAGS += -Os

FFLAGS = $(CODE_SIZE_FORTH) CONSTANT CODE-SIZE

# Source files
SOURCES = fo.c bios.c
HEADERS = 
LIBS = -ledit

FORTH_SOURCES := $(wildcard src/*.f)

# `fo` loads code.bin and data.bin at runtime
fo: $(SOURCES) $(HEADERS)
	$(CC) $(CFLAGS) $(SOURCES) $(LIBS) -o $@

# `forth` is compiled with code.inc and data.inc included
forth: $(SOURCES) $(HEADERS) code.inc data.inc
	$(CC) -DTURNKEY $(CFLAGS) $(SOURCES) $(LIBS) -o $@

code.inc data.inc: fo code.bin data.bin rth save $(FORTH_SOURCES)
	./fo rth save -e bye

code.bin code.sym: kernel.asm
	$(ASM) $(AFLAGS) -o code.bin -l code.lst $<
	@grep '^ *1' code.map | awk '{print "$$" $$2 " SYMBOL %" $$3}' > code.sym
	@rm code.map

data.bin: cross.f kernel.f code.sym
	$(FORTH) -e "$(FFLAGS)" cross.f kernel.f -e done
	@hexdump -C data.bin > data.hex

# Rebuild using ifself to compile
self:
	./forth -e "$(FFLAGS)" cross.f kernel.f -e done
	$(MAKE) test

run: forth
	@./forth

test: forth $(wildcard test/*.f)
	./forth -v test/all.f -e bye

install: forth
	cp -f forth ~/bin

clean:
	@rm -f fo forth *.bin *.inc *.lst *.map *.sym *.hex *~
