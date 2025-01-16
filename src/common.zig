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

const SbiRet = struct {
    err: usize,
    value: usize,
};

fn sbi_call(arg0: usize, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize, fid: usize, eid: usize) SbiRet {
    var err: usize = 0;
    var value: usize = 0;
    _ = asm volatile (
        \\ ecall
        : [err] "={a0}" (err),
          [value] "={a1}" (value),
        : [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
          [arg2] "{a2}" (arg2),
          [arg3] "{a3}" (arg3),
          [arg4] "{a4}" (arg4),
          [arg5] "{a5}" (arg5),
          [fid] "{a6}" (fid),
          [eid] "{a7}" (eid),
        : "memory"
    );
    return SbiRet{ .err = err, .value = value };
}

fn put_char(c: u8) void {
    _ = sbi_call(c, 0, 0, 0, 0, 0, 0, 1);
}
