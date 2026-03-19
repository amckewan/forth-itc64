# Makefile for Forth ITC-64

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
SOURCES = src/fo.c src/bios.c
HEADERS = 
LIBS = -ledit

FORTH_SOURCES := $(wildcard src/*.f)

all: forth

forth: fo code.bin data.bin rth save $(FORTH_SOURCES)
	./fo rth save -e bye
	$(CC) -DTURNKEY $(CFLAGS) $(SOURCES) $(LIBS) -o $@

fo: $(SOURCES) $(HEADERS)
	$(CC) $(CFLAGS) $(SOURCES) $(LIBS) -o $@

code.bin code.sym: src/kernel.asm
	$(ASM) $(AFLAGS) -o code.bin -l code.lst $<
	@grep '^ *1' code.map | awk '{print "$$" $$2 " SYMBOL %" $$3}' > code.sym
	@rm code.map

data.bin: cross.f src/kernel.f code.sym
	$(FORTH) -e "$(FFLAGS)" cross.f src/kernel.f -e done
	@hexdump -C data.bin > data.hex

run: forth
	@./forth

test: forth $(wildcard test/*.f)
	./forth -v test/all.f -e bye

install: forth
	cp -f forth ~/bin

clean:
	@rm -f fo forth *.bin *.inc *.lst *.map *.sym *.hex *~
