extern const __stack_top: [*]u8;
extern var __bss: [*]u8;
extern const __bss_end: [*]u8;

fn memset(buf: [*]u8, c: u8, n: usize) [*]u8 {
    var p = buf;
    for (0..n) |i| {
        p[i] = c;
    }
    return buf;
}

pub export fn kernel_main() void {
    _ = memset(__bss, 0, @intFromPtr(__bss_end) - @intFromPtr(__bss));

    while (true) {}
}

pub export fn boot() linksection(".text.boot") callconv(.Naked) void {
    _ = asm volatile (
        \\ mv sp, %[stack_top]
        \\ j kernel_main
        :
        : [stack_top] "r" (__stack_top),
    );
}
