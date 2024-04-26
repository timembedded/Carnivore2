# Build all utilities using sjasm assembler

sources := $(wildcard *.asm)

%.com: %.asm
	@echo *** Assembling $<
	@sjasm $< $@

.PHONY: all
all:	$(sources:.asm=.com)
