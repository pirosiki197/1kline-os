const common = @import("common.zig");

extern const __stack_top: anyopaque;

export fn exit() noreturn {
    while (true) {}
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
