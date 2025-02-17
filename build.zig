const std = @import("std");
const FeatureSet = std.Target.Cpu.Feature.Set;

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    var disable_features = FeatureSet.empty;
    disable_features.addFeature(@intFromEnum(std.Target.riscv.Feature.d));
    const target = b.resolveTargetQuery(.{
        .os_tag = .freestanding,
        .cpu_arch = .riscv32,
        .abi = .none,
        .ofmt = .elf,
        .cpu_features_sub = disable_features,
    });

    const exe = b.addExecutable(.{
        .name = "kernel.elf",
        .root_source_file = b.path("src/kernel.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = true,
    });
    exe.setLinkerScript(b.path("kernel.ld"));
    exe.entry = .{ .symbol_name = "boot" };

    const kernel_step = b.step("kernel", "Kernel compilation");
    kernel_step.dependOn(&b.addInstallArtifact(exe, .{}).step);

    const user_o = b.addObject(.{
        .name = "user.o",
        .root_source_file = b.path("src/user.zig"),
        .target = target,
        .optimize = optimize,
    });
    const shell_o = b.addObject(.{
        .name = "shell.o",
        .root_source_file = b.path("src/shell.zig"),
        .target = target,
        .optimize = optimize,
    });
    const shell_exe = b.addExecutable(.{
        .name = "shell.elf",
        .target = target,
        .optimize = optimize,
    });
    shell_exe.addObject(user_o);
    shell_exe.addObject(shell_o);
    shell_exe.setLinkerScript(b.path("user.ld"));
    shell_exe.entry = .{ .symbol_name = "start" };

    const user_step = b.step("user", "User compilation");
    user_step.dependOn(&b.addInstallArtifact(shell_exe, .{}).step);

    const shell_bin_cmd = b.addSystemCommand(&[_][]const u8{
        "llvm-objcopy",
        "--set-section-flags",
        ".bss=alloc,contents",
        "-O",
        "binary",
    });
    shell_bin_cmd.addFileArg(shell_exe.getEmittedBin());
    const shell_bin = shell_bin_cmd.addOutputFileArg("shell.bin");

    const shell_bin_o_cmd = b.addSystemCommand(&[_][]const u8{
        "llvm-objcopy",
        "-Ibinary",
        "-Oelf32-littleriscv",
        "--redefine-sym",
        "_binary__stdin__start=_binary_shell_bin_start",
        "--redefine-sym",
        "_binary__stdin__end=_binary_shell_bin_end",
        "--redefine-sym",
        "_binary__stdin__size=_binary_shell_bin_size",
        "-",
    });
    shell_bin_o_cmd.setStdIn(.{ .lazy_path = shell_bin });
    const shell_bin_o = shell_bin_o_cmd.addOutputFileArg("shell.bin.o");
    shell_bin_cmd.step.dependOn(&shell_exe.step);
    shell_bin_o_cmd.step.dependOn(&shell_bin_cmd.step);

    exe.step.dependOn(&shell_bin_o_cmd.step);
    exe.addObjectFile(shell_bin_o);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.getInstallStep().dependOn(&shell_bin_o_cmd.step);
    b.getInstallStep().dependOn(&b.addInstallBinFile(shell_bin_o, "shell.bin.o").step);
    b.installArtifact(exe);

    const check_step = b.step("check", "check compilation");
    check_step.dependOn(&exe.step);
}
