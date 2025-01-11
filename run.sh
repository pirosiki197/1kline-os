#!/bin/bash

set -eux

QEMU=qemu-system-riscv32

$QEMU -machine virt -bios default -nographic -serial mon:stdio --no-reboot
