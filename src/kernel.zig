const common = @import("common.zig");
const print = common.print;
const printf = common.printf;

extern const __stack_top: [*]u8;
extern const __bss: [*]u8;
extern const __bss_end: [*]u8;

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

pub export fn kernel_main() void {
    var a: usize = 5;
    var b: usize = undefined;
    printf("a = %d\n", .{a});
    _ = memcpy(@ptrCast(&b), @ptrCast(&a), @sizeOf(usize));
    printf("b = %d\n", .{b});

    while (true) {
        asm volatile ("wfi");
    }
}

pub export fn boot() linksection(".text.boot") callconv(.Naked) void {
    _ = asm volatile (
        \\ mv sp, %[stack_top]
        \\ j kernel_main
        :
        : [stack_top] "r" (&__stack_top),
    );
}
