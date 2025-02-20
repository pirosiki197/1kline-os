const common = @import("common.zig");

extern const __stack_top: anyopaque;

pub export fn start() linksection(".text.start") callconv(.Naked) void {
    asm volatile (
        \\ mv sp, %[stack_top]
        \\ call main
        \\ call exit
        :
        : [stack_top] "r" (@intFromPtr(&__stack_top)),
    );
}

fn syscall(sysno: usize, arg0: usize, arg1: usize, arg2: usize) isize {
    return asm volatile (
        \\ ecall
        : [res] "={a0}" (-> isize),
        : [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
          [arg2] "{a2}" (arg2),
          [sysno] "{a3}" (sysno),
        : "memory"
    );
}

export fn put_char(c: u8) void {
    _ = syscall(common.SYS_PUTCHAR, c, 0, 0);
}

export fn get_char() isize {
    return syscall(common.SYS_GETCHAR, 0, 0, 0);
}

export fn exit() noreturn {
    _ = syscall(common.SYS_EXIT, 0, 0, 0);
    while (true) {}
}

export fn readfile(filename: [*:0]const u8, buf: [*]u8, len: usize) isize {
    return syscall(common.SYS_READFILE, @intFromPtr(filename), @intFromPtr(buf), len);
}

export fn writefile(filename: [*:0]const u8, buf: [*]const u8, len: usize) isize {
    return syscall(common.SYS_WRITEFILE, @intFromPtr(filename), @intFromPtr(buf), len);
}
