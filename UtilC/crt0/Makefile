# Makefile for the crt0 library

BUILD_DIR := build

export AS      = sdasz80
export ASFLAGS = $(foreach def,$(DEFINES), -D$(def))

CRT0_SRC := $(wildcard *.s)
CRT0_RELS := $(addprefix $(BUILD_DIR)/,$(CRT0_SRC:.s=.rel))

.SECONDARY:
.PHONY: crt0
crt0: $(CRT0_RELS)

$(BUILD_DIR)/%.rel: %.s
	@echo Assembling $< ...
	@mkdir -p $(dir $@)
	@$(AS) $(ASFLAGS) -o $@ $^

.PHONY: clean
clean:
	@rm -rf $(BUILD_DIR)/
