zig-out/bin/kernel.elf: src/kernel.zig
	zig build -Doptimize=ReleaseSafe
