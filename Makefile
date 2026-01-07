# Makefile

ASM = nasm
CC = clang
CFLAGS = -Wall -Werror
CFLAGS += -Ofast

SOURCES = fo.c
HEADERS = 
#LIBS = -ledit -ldl
LIBS =

all: fo

fo: $(SOURCES) code.sym
	$(CC) -DKERNEL $(CFLAGS) $(SOURCES) $(LIBS) -o $@

code.bin code.lst code.map: kernel.asm
	$(ASM) -f bin -o code.bin -l code.lst $<

%.sym: %.map
	@grep '^ *1' $< | awk '{print "$$" $$1 " CONSTANT %" $$3}' > $@

#	@grep '^ *1' $< | sed 's/[[:space:]]\+/ /g' | awk '{print $$1 " CONSTANT %" $$3}' > $@

clean:
	@rm -f fo *.o *.bin *.lst *.out *.map *.sym *~
