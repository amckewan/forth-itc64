# Makefile

all: code.bin code.sym

code.bin code.lst code.map: kernel.asm
	@nasm -f bin -o code.bin -l code.lst kernel.asm

%.sym: %.map
	@grep '^ *1' $< | sed 's/[[:space:]]\+/ /g' | awk '{print $$1 " CONSTANT %" $$3}' > $@

clean:
	@rm -f *.o *.bin *.lst *.out *.map *.sym *~
