const common = @import("common.zig");

extern const __stack_top: anyopaque;

export fn exit() noreturn {
    while (true) {}
}

fn syscall(sysno: usize, arg0: usize, arg1: usize, arg2: usize) usize {
    return asm volatile (
        \\ ecall
        : [res] "={a0}" (-> usize),
        : [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
          [arg2] "{a2}" (arg2),
          [sysno] "{a3}" (sysno),
        : "memory"
    );
}

fn putchar(c: u8) void {
    syscall(common.SYS_PUTCHAR, c, 0, 0);
}

pub export fn start() linksection(".text.start") callconv(.Naked) void {
    asm volatile (
        \\ mv sp, %[stack_top]
        \\ call main
        \\ call exit
        :
        : [stack_top] "r" (@intFromPtr(&__stack_top)),
    );
}
