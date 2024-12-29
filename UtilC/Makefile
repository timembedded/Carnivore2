# Makefile for the command line tools written in C.
# The list of files to process is in the COMS variable.

# The generated files are copied to the output directory.

BUILD_DIR := build
OUTPUT_DIR := output
LIBS_DIR := .

COMS := \
	c2ramldr.com

COMS_CRT0 := crt0/build/crt0_msxdos_advanced.rel

INCLUDES := \
	include

DEFINES := \
	MSXDOS

LIBS := \
	libcommon \
	libdos

CFLAGSADD := $(foreach dir,$(INCLUDES), -I$(dir)) $(foreach def,$(DEFINES), -D$(def))
LIBFILES := $(foreach lib,$(LIBS), $(addprefix $(LIBS_DIR)/,$(lib)/build/$(lib).lib))

export CC      = sdcc
export CFLAGS  = --code-loc 0x180 --data-loc 0 -mz80 --disable-warning 283 --disable-warning 196 --disable-warning 85 -MMD $(CFLAGSADD)
export AS      = sdasz80
export ASFLAGS =
export AR      = sdar
export ARFLAGS = -rc
export OBJCOPY = objcopy

LIB_C_SRC := $(wildcard libcommon/*.c) $(wildcard libdos/*.c)
LIB_S_SRC := $(wildcard libdos/*.s)
LIB_RELS := $(addprefix $(BUILD_DIR)/,$(LIB_C_SRC:.c=.rel)) $(addprefix $(BUILD_DIR)/,$(LIB_S_SRC:.s=.rel))

.PHONY: all
all:
	@"$(MAKE)" --no-print-directory libs
	@"$(MAKE)" --no-print-directory c-tools

.SECONDARY:
.PHONY: c-tools
c-tools: $(addprefix $(BUILD_DIR)/,$(COMS))

TOOLS := $(CC) $(AS) $(AR) $(OBJCOPY)

.PHONY: prerequisites
prerequisites:
	$(foreach exec,$(TOOLS),\
		$(if $(shell which $(exec)),,$(error "ERROR: can't execute $(exec), is it installed/in PATH?")))

-include prerequisites

.PHONY: libs
libs:
	@$(foreach libfile,$(LIBFILES),\
		"$(MAKE)" --no-print-directory -C $(dir $(libfile)).. build/$(notdir $(libfile));)
	@"$(MAKE)" --no-print-directory -C $(LIBS_DIR)/crt0

-include $(BUILD_DIR)/*.d

$(LIBFILES):
	@echo Building $(notdir $@) ...
	@"$(MAKE)" --no-print-directory -C $(dir $@).. build/$(notdir $@)
	@"$(MAKE)" --no-print-directory -C $(LIBS_DIR)/crt0

$(BUILD_DIR)/%.com: $(BUILD_DIR)/%.rel $(COMS_CRT0) $(LIBFILES)
	@echo Linking $(notdir $@) ...
	@sdcc -o $(BUILD_DIR)/ $(CFLAGS) --no-std-crt0 $^
	@objcopy -I ihex -O binary $(@:.com=.ihx) $@
	@mkdir -p $(OUTPUT_DIR)
	@cp $@ $(OUTPUT_DIR)/$(notdir:$@)

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
	@rm -rf $(BUILD_DIR)/ $(OUTPUT_DIR)/
	@$(foreach libfile,$(LIBFILES),\
		"$(MAKE)" --no-print-directory -C $(dir $(libfile)).. clean;)
	@"$(MAKE)" --no-print-directory -C $(LIBS_DIR)/crt0 clean
