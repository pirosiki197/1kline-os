const std = @import("std");

pub const PAGE_SIZE = 4096;

pub const SECTOR_SIZE = 512;

pub const SYS_PUTCHAR = 1;
pub const SYS_GETCHAR = 2;
pub const SYS_EXIT = 3;
pub const SYS_READFILE = 4;
pub const SYS_WRITEFILE = 5;

pub extern fn put_char(c: u8) void;
pub extern fn get_char() isize;
pub extern fn exit() noreturn;
pub extern fn readfile(filename: [*:0]const u8, buf: [*]u8, len: usize) isize;
pub extern fn writefile(filename: [*:0]const u8, buf: [*]const u8, len: usize) isize;

pub fn memset(buf: [*]u8, c: u8, n: usize) [*]u8 {
    var p = buf;
    for (0..n) |i| {
        p[i] = c;
    }
    return buf;
}

pub fn memcpy(dst: [*]u8, src: [*]const u8, n: usize) *anyopaque {
    var p = dst;
    for (0..n) |i| {
        p[i] = src[i];
    }
    return dst;
}

const console = std.io.AnyWriter{
    .context = undefined,
    .writeFn = writeFn,
};

fn writeFn(_: *const anyopaque, bytes: []const u8) anyerror!usize {
    for (bytes) |c| {
        put_char(c);
    }
    return bytes.len;
}

pub fn print(comptime fmt: []const u8, args: anytype) void {
    console.print(fmt, args) catch unreachable;
}

pub fn cstrcpy(dst: [*]u8, src: []const u8) void {
    var i: usize = 0;
    while (src[i] != 0) : (i += 1) {
        dst[i] = src[i];
    }
    dst[i] = 0;
}

pub fn align_up(n: usize, v: usize) usize {
    return (n + v - 1) & ~(v - 1);
}
