#!/bin/bash

set -eux

QEMU=qemu-system-riscv32

make

$QEMU -machine virt -bios default -nographic -serial mon:stdio --no-reboot -kernel zig-out/bin/kernel.elf
