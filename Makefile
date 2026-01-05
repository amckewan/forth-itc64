ASM = nasm

all: forth.sym

forth.bin forth.lst forth.map: forth.asm
	@${ASM} -f bin -o forth.bin -l forth.lst forth.asm

%.sym: %.map
	@grep '^ *1' $< | sed 's/[[:space:]]\+/ /g' | awk '{print $$1, "EQU", $$3}' > $@


clean:
	@rm -f *.o *.bin *.lst *.out *.map *.sym
