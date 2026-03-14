const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const work_mod = b.addLibrary(.{
        .name = "work_module",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/work_module.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(work_mod);

    const exe = b.addExecutable(.{
        .name = "yoke_win32",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/yoke_win32.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.linkSystemLibrary("user32");
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}

