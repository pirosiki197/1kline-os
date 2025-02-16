const common = @import("common.zig");
const symbol = @import("symbol.zig");
const panic = @import("panic.zig").panic;

pub const PAGE_SIZE = 4096;

pub const SATP_SV32 = 1 << 31;
pub const PAGE_V = 1 << 0;
pub const PAGE_R = 1 << 1;
pub const PAGE_W = 1 << 2;
pub const PAGE_X = 1 << 3;
pub const PAGE_U = 1 << 4;

var next_page: usize = undefined;

pub fn alloc(n: usize) usize {
    const addr = next_page;
    next_page += n * PAGE_SIZE;

    if (next_page > @intFromPtr(&symbol.__free_ram_end)) {
        panic("out of memory: next_page=0x%x __free_ram_end=0x%x", .{ next_page, @intFromPtr(&symbol.__free_ram_end) });
    }

    _ = common.memset(@ptrFromInt(addr), 0, n);
    return addr;
}

pub fn map(table1: [*]usize, vaddr: usize, paddr: usize, flgas: usize) void {
    if (vaddr % PAGE_SIZE != 0) {
        return;
    }
    if (paddr % PAGE_SIZE != 0) {
        return;
    }

    const vpn1 = (vaddr >> 22) & 0x3ff;
    if ((table1[vpn1] & PAGE_V) == 0) {
        const pt_paddr = alloc(1);
        table1[vpn1] = ((pt_paddr / PAGE_SIZE) << 10) | PAGE_V;
    }

    const vpn0 = (vaddr >> 12) & 0x3ff;
    const table0: [*]usize = @ptrFromInt((table1[vpn1] >> 10) * PAGE_SIZE);
    table0[vpn0] = (paddr / PAGE_SIZE) << 10 | flgas | PAGE_V;
}
