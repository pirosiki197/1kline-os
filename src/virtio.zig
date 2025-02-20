const common = @import("common.zig");
const page = @import("page.zig");
const panic = @import("panic.zig").panic;
const printf = common.printf;

const PAGE_SIZE = common.PAGE_SIZE;

pub const SECTOR_SIZE = 512;
pub const VIRTQ_ENTRY_NUM = 16;
pub const VIRTIO_DEVICE_BLK = 2;
pub const VIRTIO_BLK_PADDR = 0x10001000;
pub const VIRTIO_REG_MAGIC = 0x00;
pub const VIRTIO_REG_VERSION = 0x04;
pub const VIRTIO_REG_DEVICE_ID = 0x08;
pub const VIRTIO_REG_QUEUE_SEL = 0x30;
pub const VIRTIO_REG_QUEUE_NUM_MAX = 0x34;
pub const VIRTIO_REG_QUEUE_NUM = 0x38;
pub const VIRTIO_REG_QUEUE_ALIGN = 0x3c;
pub const VIRTIO_REG_QUEUE_PFN = 0x40;
pub const VIRTIO_REG_QUEUE_READY = 0x44;
pub const VIRTIO_REG_QUEUE_NOTIFY = 0x50;
pub const VIRTIO_REG_DEVICE_STATUS = 0x70;
pub const VIRTIO_REG_DEVICE_CONFIG = 0x100;
pub const VIRTIO_STATUS_ACK = 1;
pub const VIRTIO_STATUS_DRIVER = 2;
pub const VIRTIO_STATUS_DRIVER_OK = 4;
pub const VIRTIO_STATUS_FEAT_OK = 8;
pub const VIRTQ_DESC_F_NEXT = 1;
pub const VIRTQ_DESC_F_WRITE = 2;
pub const VIRTQ_AVAIL_F_NO_INTERRUPT = 1;
pub const VIRTIO_BLK_T_IN = 0;
pub const VIRTIO_BLK_T_OUT = 1;

const virtq_desc = extern struct {
    addr: u64 align(1),
    len: u32 align(1),
    flags: u16 align(1),
    next: u16 align(1),
};

const virtq_avail = extern struct {
    flags: u16 align(1),
    index: u16 align(1),
    ring: [VIRTQ_ENTRY_NUM]u16 align(1),
};

const virtq_used_elem = extern struct {
    id: u32 align(1),
    len: u32 align(1),
};

const virtq_used = extern struct {
    flags: u16 align(1),
    index: u16 align(1),
    ring: [VIRTQ_ENTRY_NUM]virtq_used_elem align(1),
};

const virtio_virtq = extern struct {
    descs: [VIRTQ_ENTRY_NUM]virtq_desc align(1),
    avail: virtq_avail align(1),
    used: virtq_used align(PAGE_SIZE),
    queue_index: usize align(1),
    used_index: *volatile u16 align(1),
    last_used_index: u16 align(1),
};

const virtio_blk_req = extern struct {
    type_: u32 align(1),
    reserved: u32 align(1),
    sector: u64 align(1),
    data: [512]u8 align(1),
    status: u8 align(1),
};

fn reg_read32(offset: usize) u32 {
    return @as(*volatile u32, @ptrFromInt(VIRTIO_BLK_PADDR + offset)).*;
}

fn reg_read64(offset: usize) u64 {
    return @as(*volatile u64, @ptrFromInt(VIRTIO_BLK_PADDR + offset)).*;
}

fn reg_write32(offset: usize, value: u32) void {
    @as(*volatile u32, @ptrFromInt(VIRTIO_BLK_PADDR + offset)).* = value;
}

fn reg_fetch_and_or32(offset: usize, value: u32) void {
    reg_write32(offset, reg_read32(offset) | value);
}

var blk_request_vq: *virtio_virtq = undefined;
var blk_req: *virtio_blk_req = undefined;
var blk_req_paddr: usize = undefined;
var blk_capacity: u64 = undefined;

pub fn init() void {
    if (reg_read32(VIRTIO_REG_MAGIC) != 0x74726976) {
        panic("virtio: invalid magic value", .{});
    }
    if (reg_read32(VIRTIO_REG_VERSION) != 1) {
        panic("virtio: invalid version", .{});
    }
    if (reg_read32(VIRTIO_REG_DEVICE_ID) != VIRTIO_DEVICE_BLK) {
        panic("virtio: invalid device id", .{});
    }

    // 1. Reset the device
    reg_write32(VIRTIO_REG_DEVICE_STATUS, 0);
    // 2. Set the ACKNOWLEDGE status bit: the guest OS has noticed the device
    reg_fetch_and_or32(VIRTIO_REG_DEVICE_STATUS, VIRTIO_STATUS_ACK);
    // 3. Set the DRIVER status bit
    reg_fetch_and_or32(VIRTIO_REG_DEVICE_STATUS, VIRTIO_STATUS_DRIVER);
    // 5. Set the FEATURES_OK status bit
    reg_fetch_and_or32(VIRTIO_REG_DEVICE_STATUS, VIRTIO_STATUS_FEAT_OK);
    // 7. Perform device-specific setup, including discovery of virtqueues for the device
    blk_request_vq = virtq_init(0);
    // 8. Set the DRIVER_OK status bit
    reg_write32(VIRTIO_REG_DEVICE_STATUS, VIRTIO_STATUS_DRIVER_OK);

    blk_capacity = reg_read64(VIRTIO_REG_DEVICE_CONFIG + 0) * SECTOR_SIZE;
    printf("virtio-blk: capacity is %d bytes\n", .{blk_capacity});

    blk_req_paddr = page.alloc(common.align_up(@sizeOf(virtio_blk_req), PAGE_SIZE) / PAGE_SIZE);
    blk_req = @ptrFromInt(blk_req_paddr);
}

fn virtq_init(index: usize) *virtio_virtq {
    const virtq_paddr = page.alloc(common.align_up(@sizeOf(virtio_virtq), PAGE_SIZE) / PAGE_SIZE);
    const vq: *virtio_virtq = @ptrFromInt(virtq_paddr);
    vq.queue_index = index;
    vq.used_index = &vq.used.index;
    // 1. Select the queue writing its index (first queue is 0) to QueueSel
    reg_write32(VIRTIO_REG_QUEUE_SEL, index);
    // 5. Notify the device about the queue size by writing the size to QueueNum
    reg_write32(VIRTIO_REG_QUEUE_NUM, VIRTQ_ENTRY_NUM);
    // 6. Notify the device about the used alignment by writing its value in bytes to QueueAlign
    reg_write32(VIRTIO_REG_QUEUE_ALIGN, 0);
    // 7. Write the physical number of the first page of the queue to the QueuePFN register
    reg_write32(VIRTIO_REG_QUEUE_PFN, virtq_paddr);
    return vq;
}

fn virtq_kick(vq: *virtio_virtq, desc_index: u16) void {
    vq.avail.ring[vq.avail.index % VIRTQ_ENTRY_NUM] = desc_index;
    vq.avail.index += 1;

    reg_write32(VIRTIO_REG_QUEUE_NOTIFY, vq.queue_index);
    vq.last_used_index += 1;
}

fn virtq_is_busy(vq: *const virtio_virtq) bool {
    return vq.last_used_index != vq.used_index.*;
}

pub fn read_write_disk(buf: [*]u8, sector: usize, is_write: bool) void {
    if (sector >= blk_capacity / SECTOR_SIZE) {
        printf("virtio: tried to read/write sector=%d, but capacity is %d\n", .{ sector, blk_capacity / SECTOR_SIZE });
        return;
    }

    blk_req.sector = sector;
    blk_req.type_ = if (is_write) VIRTIO_BLK_T_OUT else VIRTIO_BLK_T_IN;
    if (is_write) {
        _ = common.memcpy(&blk_req.data, buf, SECTOR_SIZE);
    }

    const vq = blk_request_vq;
    vq.descs[0].addr = blk_req_paddr;
    vq.descs[0].len = @sizeOf(u32) * 2 + @sizeOf(u64);
    vq.descs[0].flags = VIRTQ_DESC_F_NEXT;
    vq.descs[0].next = 1;

    vq.descs[1].addr = blk_req_paddr + @offsetOf(virtio_blk_req, "data");
    vq.descs[1].len = SECTOR_SIZE;
    if (is_write) {
        vq.descs[1].flags = VIRTQ_DESC_F_NEXT;
    } else {
        vq.descs[1].flags = VIRTQ_DESC_F_NEXT | VIRTQ_DESC_F_WRITE;
    }
    vq.descs[1].next = 2;

    vq.descs[2].addr = blk_req_paddr + @offsetOf(virtio_blk_req, "status");
    vq.descs[2].len = @sizeOf(u8);
    vq.descs[2].flags = VIRTQ_DESC_F_WRITE;

    virtq_kick(vq, 0);

    while (virtq_is_busy(vq)) {}

    if (blk_req.status != 0) {
        printf("virtio: warn: failed to read/write sector=%d status=%d\n", .{ sector, blk_req.status });
        return;
    }

    if (!is_write) {
        _ = common.memcpy(buf, &blk_req.data, SECTOR_SIZE);
    }
}
