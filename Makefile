zig-out/bin/kernel.elf: src/kernel.zig
	zig build -Doptimize=ReleaseSafe

.PHONY: objdump
objdump:
	llvm-objdump -d zig-out/bin/kernel.elf
