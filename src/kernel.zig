const sbi = @cImport({
    @cInclude("sbi.h");
});

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

fn put_char(c: u8) void {
    _ = sbi.sbi_call(c, 0, 0, 0, 0, 0, 0, 1);
}

pub export fn kernel_main() void {
    const msg = "\n\nHello World!\n";
    for (0..msg.len) |i| {
        put_char(msg[i]);
    }

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
