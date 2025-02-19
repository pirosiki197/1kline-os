const std = @import("std");

const symbol = @import("symbol.zig");
const common = @import("common.zig");
const proc = @import("process.zig");
const virtio = @import("virtio.zig");
const Process = proc.Process;
const page = @import("page.zig");
const print = common.print;
const printf = common.printf;
const panic = @import("panic.zig").panic;

const SCAUSE_ECALL = 8;

const TrapFrame = packed struct {
    ra: usize,
    gp: usize,
    tp: usize,
    t0: usize,
    t1: usize,
    t2: usize,
    t3: usize,
    t4: usize,
    t5: usize,
    t6: usize,
    a0: usize,
    a1: usize,
    a2: usize,
    a3: usize,
    a4: usize,
    a5: usize,
    a6: usize,
    a7: usize,
    s0: usize,
    s1: usize,
    s2: usize,
    s3: usize,
    s4: usize,
    s5: usize,
    s6: usize,
    s7: usize,
    s8: usize,
    s9: usize,
    s10: usize,
    s11: usize,
    sp: usize,
};

inline fn read_csr(comptime reg: []const u8) u32 {
    return asm volatile ("csrr %[value], " ++ reg
        : [value] "=r" (-> u32),
    );
}

inline fn write_csr(comptime reg: []const u8, value: u32) void {
    asm volatile ("csrw " ++ reg ++ ", %[value]"
        :
        : [value] "r" (value),
    );
}

fn memset(buf: [*]u8, c: u8, n: usize) [*]u8 {
    var p = buf;
    for (0..n) |i| {
        p[i] = c;
    }
    return buf;
}

fn memcpy(dst: [*]u8, src: [*]const u8, n: usize) *anyopaque {
    var p = dst;
    for (0..n) |i| {
        p[i] = src[i];
    }
    return dst;
}

export fn put_char(c: u8) void {
    _ = sbi_call(c, 0, 0, 0, 0, 0, 0, 1);
}

export fn get_char() isize {
    const ret = sbi_call(0, 0, 0, 0, 0, 0, 0, 2);
    return ret.err;
}

const SbiRet = struct {
    err: isize,
    value: isize,
};

fn sbi_call(arg0: usize, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize, fid: usize, eid: usize) SbiRet {
    var err: isize = 0;
    var value: isize = 0;
    _ = asm volatile (
        \\ ecall
        : [err] "={a0}" (err),
          [value] "={a1}" (value),
        : [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
          [arg2] "{a2}" (arg2),
          [arg3] "{a3}" (arg3),
          [arg4] "{a4}" (arg4),
          [arg5] "{a5}" (arg5),
          [fid] "{a6}" (fid),
          [eid] "{a7}" (eid),
        : "memory"
    );
    return SbiRet{ .err = err, .value = value };
}

fn kernel_entry() align(4) callconv(.Naked) void {
    asm volatile (
        \\ csrrw sp, sscratch, sp
        \\
        \\ addi sp, sp, -4 * 31
        \\ sw ra, 4 * 0(sp)
        \\ sw gp, 4 * 1(sp)
        \\ sw tp, 4 * 2(sp)
        \\ sw t0, 4 * 3(sp)
        \\ sw t1, 4 * 4(sp)
        \\ sw t2, 4 * 5(sp)
        \\ sw t3, 4 * 6(sp)
        \\ sw t4, 4 * 7(sp)
        \\ sw t5, 4 * 8(sp)
        \\ sw t6, 4 * 9(sp)
        \\ sw a0, 4 * 10(sp)
        \\ sw a1, 4 * 11(sp)
        \\ sw a2, 4 * 12(sp)
        \\ sw a3, 4 * 13(sp)
        \\ sw a4, 4 * 14(sp)
        \\ sw a5, 4 * 15(sp)
        \\ sw a6, 4 * 16(sp)
        \\ sw a7, 4 * 17(sp)
        \\ sw s0, 4 * 18(sp)
        \\ sw s1, 4 * 19(sp)
        \\ sw s2, 4 * 20(sp)
        \\ sw s3, 4 * 21(sp)
        \\ sw s4, 4 * 22(sp)
        \\ sw s5, 4 * 23(sp)
        \\ sw s6, 4 * 24(sp)
        \\ sw s7, 4 * 25(sp)
        \\ sw s8, 4 * 26(sp)
        \\ sw s9, 4 * 27(sp)
        \\ sw s10, 4 * 28(sp)
        \\ sw s11, 4 * 29(sp)
        \\
        \\ csrr a0, sscratch
        \\ sw a0, 4 * 30(sp)
        \\
        \\ addi a0, sp, 4*31
        \\ csrw sscratch, a0
        \\
        \\ mv a0, sp
        \\ call handle_trap
        \\
        \\ lw ra, 4 * 0(sp)
        \\ lw gp, 4 * 1(sp)
        \\ lw tp, 4 * 2(sp)
        \\ lw t0, 4 * 3(sp)
        \\ lw t1, 4 * 4(sp)
        \\ lw t2, 4 * 5(sp)
        \\ lw t3, 4 * 6(sp)
        \\ lw t4, 4 * 7(sp)
        \\ lw t5, 4 * 8(sp)
        \\ lw t6, 4 * 9(sp)
        \\ lw a0, 4 * 10(sp)
        \\ lw a1, 4 * 11(sp)
        \\ lw a2, 4 * 12(sp)
        \\ lw a3, 4 * 13(sp)
        \\ lw a4, 4 * 14(sp)
        \\ lw a5, 4 * 15(sp)
        \\ lw a6, 4 * 16(sp)
        \\ lw a7, 4 * 17(sp)
        \\ lw s0, 4 * 18(sp)
        \\ lw s1, 4 * 19(sp)
        \\ lw s2, 4 * 20(sp)
        \\ lw s3, 4 * 21(sp)
        \\ lw s4, 4 * 22(sp)
        \\ lw s5, 4 * 23(sp)
        \\ lw s6, 4 * 24(sp)
        \\ lw s7, 4 * 25(sp)
        \\ lw s8, 4 * 26(sp)
        \\ lw s9, 4 * 27(sp)
        \\ lw s10, 4 * 28(sp)
        \\ lw s11, 4 * 29(sp)
        \\ lw sp, 4 * 30(sp)
        \\ sret
    );
}

pub export fn handle_trap(f: *TrapFrame) void {
    const scause = read_csr("scause");
    const stval = read_csr("stval");
    var user_pc = read_csr("sepc");

    if (scause == SCAUSE_ECALL) {
        handle_syscall(f);
        user_pc += 4;
    } else {
        panic("unexpected trap scause=%x, stval=%x, sepc=%x\n", .{ scause, stval, user_pc });
    }

    write_csr("sepc", user_pc);
}

fn handle_syscall(f: *TrapFrame) void {
    switch (f.a3) {
        common.SYS_PUTCHAR => put_char(@intCast(f.a0)),
        common.SYS_GETCHAR => {
            while (true) {
                const ch = get_char();
                if (ch >= 0) {
                    f.a0 = @intCast(ch);
                    break;
                }
                proc.yield();
            }
        },
        common.SYS_EXIT => {
            printf("process %d exited\n", .{proc.current().pid});
            proc.current().exit();
            proc.yield();
            panic("unreachable", .{});
        },
        else => panic("unexpected syscall a3=0x%x\n", .{f.a3}),
    }
}

fn delay() void {
    for (0..1000000) |_| {
        asm volatile ("nop");
    }
}

pub export fn kernel_main() void {
    _ = memset(@ptrCast(@constCast(&symbol.__bss)), 0, @intFromPtr(&symbol.__bss_end) - @intFromPtr(&symbol.__bss));

    write_csr("stvec", @intFromPtr(&kernel_entry));

    page.init();
    virtio.init();
    proc.init();

    var buf: [virtio.SECTOR_SIZE]u8 = undefined;
    virtio.read_write_disk(&buf, 0, false);
    printf("first sector: %s\n", .{buf});
    std.mem.copyForwards(u8, &buf, "Hello from kernel!\n");
    virtio.read_write_disk(&buf, 0, true);

    _ = Process.create(@intFromPtr(&symbol._binary_shell_bin_start), @intFromPtr(&symbol._binary_shell_bin_size));

    proc.yield();

    panic("switched to idle process", .{});
}

pub export fn boot() linksection(".text.boot") callconv(.Naked) void {
    _ = asm volatile (
        \\ mv sp, %[stack_top]
        \\ j kernel_main
        :
        : [stack_top] "r" (&symbol.__stack_top),
    );
}
