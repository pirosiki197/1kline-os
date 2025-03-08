const std = @import("std");

const common = @import("common.zig");
const virtio = @import("virtio.zig");
const panic = @import("panic.zig").panic;
const printf = common.printf;
const SECTOR_SIZE = common.SECTOR_SIZE;

const TarHeader = extern struct {
    name: [100]u8 align(1),
    mode: [8]u8 align(1),
    uid: [8]u8 align(1),
    gid: [8]u8 align(1),
    size: [12]u8 align(1),
    mtime: [12]u8 align(1),
    checksum: [8]u8 align(1),
    type_: u8 align(1),
    linkname: [100]u8 align(1),
    magic: [6]u8 align(1),
    version: [2]u8 align(1),
    uname: [32]u8 align(1),
    gname: [32]u8 align(1),
    devmajor: [8]u8 align(1),
    devminor: [8]u8 align(1),
    prefix: [155]u8 align(1),
    padding: [12]u8 align(1),
    data: [*]u8 align(1),
};

pub const File = struct {
    in_use: bool,
    name: [100:0]u8,
    data: [1024]u8,
    size: usize,
};

const FILES_MAX = 2;
const DISK_MAX_SIZE = common.align_up(@sizeOf(File) * FILES_MAX, SECTOR_SIZE);

var files: [FILES_MAX]File = undefined;
var disk: [DISK_MAX_SIZE]u8 = undefined;

fn oct2int(oct: []const u8) usize {
    var dec: usize = 0;
    for (oct) |c| {
        if (c < '0' or c > '7') {
            break;
        }
        dec = dec * 8 + (c - '0');
    }
    return dec;
}

pub fn init() void {
    for (0..@sizeOf(@TypeOf(disk)) / SECTOR_SIZE) |sector| {
        virtio.read_write_disk(@ptrCast(&disk[sector * SECTOR_SIZE]), sector, false);
    }

    var off: usize = 0;
    for (0..FILES_MAX) |i| {
        const header: *TarHeader = @ptrCast(&disk[off]);
        if (header.name[0] == 0) {
            break;
        }

        if (std.mem.orderZ(u8, @ptrCast(&header.magic), "ustar") != .eq) {
            panic("invalid tar header magic: \"%s\"", .{header.magic});
        }

        const filesz = oct2int(&header.size);
        const file = &files[i];
        file.in_use = true;
        std.mem.copyForwards(u8, &file.name, &header.name);
        _ = common.memcpy(&file.data, @ptrCast(&header.data), filesz);
        file.size = filesz;
        printf("file: %s, size=%d\n", .{ &file.name, file.size });
        off += common.align_up(@sizeOf(TarHeader) + filesz, SECTOR_SIZE);
    }
}

pub fn flush() void {
    const strcpy = common.cstrcpy;

    _ = common.memset(&disk, 0, @sizeOf(@TypeOf(disk)));
    var off: usize = 0;
    for (&files) |*file| {
        if (!file.in_use) continue;

        const header: *TarHeader = @ptrCast(&disk[off]);
        _ = common.memset(@ptrCast(header), 0, @sizeOf(TarHeader));
        strcpy(&header.name, &file.name);
        strcpy(&header.mode, "000644");
        strcpy(&header.magic, "ustar");
        strcpy(&header.version, "00");
        header.type_ = '0';

        var filesz = file.size;
        var hi: isize = @sizeOf(@TypeOf(header.size));
        while (hi > 0) : (hi -= 1) {
            header.size[@intCast(hi - 1)] = @intCast((filesz % 8) + '0');
            filesz /= 8;
        }

        var checksum: usize = ' ' * @sizeOf(@TypeOf(header.checksum));
        for (0..@sizeOf(TarHeader)) |i| {
            checksum += disk[off + i];
        }

        hi = 5;
        while (hi >= 0) : (hi -= 1) {
            header.checksum[@intCast(hi)] = @intCast((checksum % 8) + '0');
            checksum /= 8;
        }

        _ = common.memcpy(@ptrCast(&header.data), &file.data, file.size);
        off += common.align_up(@sizeOf(TarHeader) + file.size, SECTOR_SIZE);
    }

    for (0..@sizeOf(@TypeOf(disk)) / SECTOR_SIZE) |sector| {
        virtio.read_write_disk(@ptrCast(&disk[sector * SECTOR_SIZE]), sector, true);
    }
}

pub fn lookup(filename: [*:0]const u8) ?*File {
    for (&files) |*file| {
        if (std.mem.orderZ(u8, filename, &file.name) == .eq) {
            return file;
        }
    }
    return null;
}
