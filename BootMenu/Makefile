# Build bootmenu using sjasm assembler

sources := $(wildcard *.ASM)

%.BIN: %.ASM
	@echo *** Assembling $<
	@sjasm $< $@

.PHONY: all
all:	$(sources:.ASM=.BIN)
