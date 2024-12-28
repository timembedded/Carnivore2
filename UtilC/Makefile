# Makefile for the command line tools written in C.
# The list of files to process is in the COMS variable.

# The generated files are copied to the bin/tools directory.

COMS := \
	test80c.com \
	testdos.com \
	c2ramldr.com

BUILD_DIR := $(PWD)/build
OUTPUT_DIR := $(PWD)/output

export CC      = sdcc
export CFLAGS  = --code-loc 0x180 --data-loc 0 -mz80 --disable-warning 283 --disable-warning 196 --disable-warning 85 -Iinclude -DMSXDOS
export AS      = sdasz80
export ASFLAGS =
export AR      = sdar
export ARFLAGS = -rc
export OBJCOPY = objcopy

LIB_C_SRC := $(wildcard libcommon/*.c) $(wildcard libdos/*.c)
LIB_S_SRC := $(wildcard libdos/*.s)
LIB_RELS := $(addprefix $(BUILD_DIR)/,$(LIB_C_SRC:.c=.rel)) $(addprefix $(BUILD_DIR)/,$(LIB_S_SRC:.s=.rel))

.SECONDARY:
.PHONY: c-tools
c-tools: $(addprefix $(BUILD_DIR)/,$(COMS))

TOOLS := $(CC) $(AS) $(AR) $(OBJCOPY)

.PHONY: prerequisites
prerequisites:
	$(foreach exec,$(TOOLS),\
		$(if $(shell which $(exec)),,$(error "ERROR: can't execute $(exec), is it installed/in PATH?")))

-include prerequisites

$(BUILD_DIR)/%.com: %.c $(BUILD_DIR)/crt0/crt0_msxdos_advanced.rel $(BUILD_DIR)/libs.lib
	@echo Compiling $< ...
	@sdcc -o $(BUILD_DIR)/ $(CFLAGS) --no-std-crt0 $^
	@objcopy -I ihex -O binary $(@:.com=.ihx) $@
	@mkdir -p $(OUTPUT_DIR)
	@cp $@ $(OUTPUT_DIR)/$(notdir:$@)

$(BUILD_DIR)/libs.lib: $(LIB_RELS)
	@echo Creating $@ ...
	@$(AR) $(ARFLAGS) $@ $^

$(BUILD_DIR)/%.rel: %.c
	@echo Compiling $< ...
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -o $@ -c $^

$(BUILD_DIR)/%.rel: %.s
	@echo Assembling $< ...
	@mkdir -p $(dir $@)
	@$(AS) $(ASFLAGS) -o $@ $^

.PHONY: clean
clean:
	@rm -r $(BUILD_DIR)/ $(OUTPUT_DIR)/
