const common = @import("common.zig");
const print = common.print;
const printf = common.printf;

extern const __stack_top: [*]u8;
extern const __bss: [*]u8;
extern const __bss_end: [*]u8;
extern const __free_ram: [*]u8;
extern const __free_ram_end: [*]u8;
var next_page: usize = undefined;

fn alloc_page(n: usize) usize {
    const addr = next_page;
    next_page += n * common.PAGE_SIZE;

    if (next_page > @intFromPtr(__free_ram_end)) {
        panic("out of memory", .{});
    }

    _ = memset(@ptrFromInt(addr), 0, n);
    return addr;
}

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

fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    printf("PANIC: " ++ fmt ++ "\n", args);
    while (true) {}
}

fn kernel_entry() align(4) callconv(.Naked) void {
    asm volatile (
        \\ csrw sscratch, sp
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

pub export fn handle_trap(_: *TrapFrame) void {
    const scause = read_csr("scause");
    const stval = read_csr("stval");
    const user_pc = read_csr("sepc");

    panic("unexpected trap scause=%x, stval=%x, sepc=%x\n", .{ scause, stval, user_pc });
}

pub export fn kernel_main() void {
    _ = memset(__bss, 0, @intFromPtr(__bss_end) - @intFromPtr(__bss));

    next_page = @intFromPtr(__free_ram);

    const paddr0 = alloc_page(2);
    const paddr1 = alloc_page(1);
    printf("alloc_page test: paddr0=%x\n", .{paddr0});
    printf("alloc_page test: paddr1=%x\n", .{paddr1});

    panic("booted!", .{});
}

pub export fn boot() linksection(".text.boot") callconv(.Naked) void {
    _ = asm volatile (
        \\ mv sp, %[stack_top]
        \\ j kernel_main
        :
        : [stack_top] "r" (&__stack_top),
    );
}
