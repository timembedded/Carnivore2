# Build all utilities using sjasm assembler

sources := $(wildcard *.asm)

includes := $(wildcard lib/*.inc)

%.com: %.asm $(includes)
	@echo *** Assembling $<
	@sjasm $< $@

.PHONY: all
all:	$(sources:.asm=.com)

.PHONY: clean
clean:
	@rm *.com
