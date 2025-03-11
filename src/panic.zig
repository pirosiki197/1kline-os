const print = @import("common.zig").print;

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    print("PANIC: " ++ fmt ++ "\n", args);
    while (true) {}
}
