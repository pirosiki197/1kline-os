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

extern const __stack_top: [*]u8;
extern const __bss: [*]u8;
extern const __bss_end: [*]u8;

fn memset(buf: [*]u8, c: u8, n: usize) [*]u8 {
    var p = buf;
    for (0..n) |i| {
        p[i] = c;
    }
    return buf;
}

fn put_char(c: u8) void {
    _ = sbi_call(c, 0, 0, 0, 0, 0, 0, 1);
}

pub export fn kernel_main() void {
    const msg = "\n\nHello World!\n";
    for (msg) |c| {
        put_char(c);
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
