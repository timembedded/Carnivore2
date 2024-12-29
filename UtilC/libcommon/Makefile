# Makefile for a library

LIBRARY := $(lastword $(subst /, ,$(basename $(realpath .)))).lib

BUILD_DIR := build

INCLUDES := \
	../include

DEFINES := \
	MSXDOS

CFLAGSADD := $(foreach dir,$(INCLUDES), -I$(dir)) $(foreach def,$(DEFINES), -D$(def))

export CC      = sdcc
export CFLAGS  = --code-loc 0x180 --data-loc 0 -mz80 --disable-warning 283 --disable-warning 196 --disable-warning 85 -MMD $(CFLAGSADD)
export AS      = sdasz80
export ASFLAGS =
export AR      = sdar
export ARFLAGS = -rc
export OBJCOPY = objcopy

LIB_C_SRC := $(wildcard *.c)
LIB_S_SRC := $(wildcard *.s)
LIB_RELS := $(addprefix $(BUILD_DIR)/,$(LIB_C_SRC:.c=.rel)) $(addprefix $(BUILD_DIR)/,$(LIB_S_SRC:.s=.rel))

.SECONDARY:
.PHONY: lib
lib: $(BUILD_DIR)/$(LIBRARY)

-include $(BUILD_DIR)/*.d

$(BUILD_DIR)/$(LIBRARY): $(LIB_RELS)
	@echo Creating $@ ...
	@$(AR) $(ARFLAGS) $@ $^

$(BUILD_DIR)/%.rel: %.c
	@echo Compiling $< ...
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -o $@ -c $<

$(BUILD_DIR)/%.rel: %.s
	@echo Assembling $< ...
	@mkdir -p $(dir $@)
	@$(AS) $(ASFLAGS) -o $@ $^

.PHONY: clean
clean:
	@rm -rf $(BUILD_DIR)/
