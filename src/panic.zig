const printf = @import("common.zig").printf;

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    printf("PANIC: " ++ fmt ++ "\n", args);
    while (true) {}
}
