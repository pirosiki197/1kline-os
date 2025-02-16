const panic = @import("panic.zig").panic;

const PROCS_MAX = 8;

var current_proc: *Process = undefined;
var idle_proc: *Process = undefined;

const ProcessState = enum {
    Unused,
    Runnable,
};

pub const Process = struct {
    pid: i32 = 0,
    state: ProcessState = .Unused,
    sp: usize = 0, // stack pointer at the time of the last context switch
    stack: [8192]u8 = undefined,
};

var processes: [PROCS_MAX]Process = .{.{}} ** PROCS_MAX;

inline fn switch_context(prev_sp: *usize, next_sp: *usize) void {
    asm volatile (
        \\ addi sp, sp, -13 * 4
        \\ sw ra, 0 * 4(sp)
        \\ sw s0, 1 * 4(sp)
        \\ sw s1, 2 * 4(sp)
        \\ sw s2, 3 * 4(sp)
        \\ sw s3, 4 * 4(sp)
        \\ sw s4, 5 * 4(sp)
        \\ sw s5, 6 * 4(sp)
        \\ sw s6, 7 * 4(sp)
        \\ sw s7, 8 * 4(sp)
        \\ sw s8, 9 * 4(sp)
        \\ sw s9, 10 * 4(sp)
        \\ sw s10, 11 * 4(sp)
        \\ sw s11, 12 * 4(sp)
        \\
        \\ sw sp, (a0)
        \\ lw sp, (a1)
        \\
        \\ lw ra, 0 * 4(sp)
        \\ lw s0, 1 * 4(sp)
        \\ lw s1, 2 * 4(sp)
        \\ lw s2, 3 * 4(sp)
        \\ lw s3, 4 * 4(sp)
        \\ lw s4, 5 * 4(sp)
        \\ lw s5, 6 * 4(sp)
        \\ lw s6, 7 * 4(sp)
        \\ lw s7, 8 * 4(sp)
        \\ lw s8, 9 * 4(sp)
        \\ lw s9, 10 * 4(sp)
        \\ lw s10, 11 * 4(sp)
        \\ lw s11, 12 * 4(sp)
        \\ addi sp, sp, 13 * 4
        \\ ret
        :
        : [prev_sp] "{a0}" (prev_sp),
          [next_sp] "{a1}" (next_sp),
    );
}

pub fn yield() void {
    var next = idle_proc;
    for (0..PROCS_MAX) |i| {
        const proc = &processes[@intCast(@mod(current_proc.pid + @as(i32, @intCast(i)), PROCS_MAX))];
        if (proc.state == .Runnable and proc.pid > 0) {
            next = proc;
            break;
        }
    }

    asm volatile (
        \\ csrw sscratch, %[sscratch]
        :
        : [sscratch] "r" (@intFromPtr(&next.stack) + next.stack.len),
    );

    if (next == current_proc) {
        return;
    }

    const prev = current_proc;
    current_proc = next;
    switch_context(&prev.sp, &next.sp);
}

pub fn create_process(pc: usize) *Process {
    var maybe_proc: ?*Process = null;
    for (0..PROCS_MAX) |i| {
        if (processes[i].state == .Unused) {
            processes[i].pid = @intCast(i + 1);
            processes[i].state = .Runnable;
            maybe_proc = &processes[i];
            break;
        }
    }

    if (maybe_proc) |proc| {
        var sp: [*]usize = @ptrFromInt(@intFromPtr(&proc.stack) + proc.stack.len);
        // s11 - s0
        for (0..12) |_| {
            sp -= 1;
            sp[0] = 0;
        }
        // ra
        sp -= 1;
        sp[0] = pc;

        proc.sp = @intFromPtr(sp);

        return proc;
    } else {
        panic("out of processes", .{});
    }
}

pub fn init_processes() void {
    idle_proc = create_process(0);
    idle_proc.pid = -1;
    current_proc = idle_proc;
}
