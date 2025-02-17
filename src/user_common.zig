const common = @import("common.zig");

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

pub fn printf(comptime fmt: []const u8, args: anytype) void {
    const args_type = @typeInfo(@TypeOf(args));
    if (args_type != .Struct) {
        @compileError("print() requires a struct argument");
    }
    const fields_info = args_type.Struct.fields;

    comptime var idx: usize = 0;
    comptime var field_idx: usize = 0;
    inline while (idx < fmt.len) : (idx += 1) {
        if (fmt[idx] != '%') {
            put_char(fmt[idx]);
            continue;
        }

        idx += 1;
        switch (fmt[idx]) {
            '%' => put_char('%'),
            's' => {
                const field = @field(args, fields_info[field_idx].name);
                for (field) |c| {
                    put_char(c);
                }
                field_idx += 1;
            },
            'd' => {
                var value: u32 = blk: {
                    const field = @field(args, fields_info[field_idx].name);
                    const _value: i32 = @intCast(field);
                    if (_value < 0) {
                        put_char('-');
                        break :blk @intCast(-_value);
                    }
                    break :blk @intCast(_value);
                };

                var divisor: u32 = 1;
                while (value / divisor >= 10) {
                    divisor *= 10;
                }

                while (divisor > 0) {
                    put_char('0' + @as(u8, @intCast(value / divisor)));
                    value %= divisor;
                    divisor /= 10;
                }
                field_idx += 1;
            },
            'x' => {
                const value: usize = @intCast(@field(args, fields_info[field_idx].name));
                comptime var i: isize = 7;
                inline while (i >= 0) : (i -= 1) {
                    const nibble = (value >> (i * 4)) & 0xf;
                    if (nibble < 10) {
                        put_char('0' + @as(u8, @intCast(nibble)));
                    } else {
                        put_char('a' + @as(u8, @intCast(nibble - 10)));
                    }
                }
                field_idx += 1;
            },
            else => {},
        }
    }
}

pub fn print(s: []const u8) void {
    for (s) |c| {
        put_char(c);
    }
}

fn put_char(c: u8) void {
    _ = syscall(common.SYS_PUTCHAR, c, 0, 0);
}
