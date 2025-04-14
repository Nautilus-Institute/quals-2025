const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .os_tag = .linux,
            .cpu_arch = .x86_64,
            .ofmt = .elf,
        },
    });
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });

    const exe = b.addExecutable(.{
        .name = "youwouldntdownloada3dprinter",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = true,
        .pic = true,
        .error_tracing = false,
        .unwind_tables = false,
        .omit_frame_pointer = true,
    });
    exe.pie = true;

    b.installArtifact(exe);
}
