const std = @import("std");

const common = @import("common.zig");
const printf = common.printf;
const print = common.print;
const put_char = common.put_char;
const exit = common.exit;

pub export fn main() void {
    while (true) {
        prompt: {
            print("shell> ");
            var buf: [128]u8 = undefined;
            var cmdline: []const u8 = undefined;
            var i: usize = 0;
            while (true) : (i += 1) {
                const ch: u8 = @intCast(common.get_char());
                put_char(ch);
                if (i == buf.len - 1) {
                    print("command line too long\n");
                    break :prompt;
                } else if (ch == '\r') {
                    put_char('\n');
                    cmdline = buf[0..i];
                    break;
                } else {
                    buf[i] = ch;
                }
            }

            if (std.mem.eql(u8, cmdline, "hello")) {
                print("Hello, world from shell!\n");
            } else if (std.mem.eql(u8, cmdline, "exit")) {
                exit();
            } else {
                printf("Unknown command: %s\n", .{cmdline});
            }
        }
    }
}
