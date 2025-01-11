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

pub export fn kernel_main() void {
    print("Hello, world!\n");
    printf("Hello, %s!\n", .{"world"});
    printf("1 + 2 = %d\n", .{3});
    printf("0x12345678 = %x\n", .{0x12345678});

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
