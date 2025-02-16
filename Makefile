SRC_FILES := $(shell find src -name '*.zig')

zig-out/bin/kernel.elf: $(SRC_FILES) build.zig kernel.ld
	zig build -Doptimize=ReleaseFast

.PHONY: objdump
objdump:
	llvm-objdump -d zig-out/bin/kernel.elf
