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
    exe.linkSystemLibrary("gdi32");

    const install_work_mod = b.addInstallArtifact(work_mod, .{});
    const install_exe = b.addInstallArtifact(exe, .{});

    b.getInstallStep().dependOn(&install_work_mod.step);
    b.getInstallStep().dependOn(&install_exe.step);

    // A build path dedicated to hot-reloaded so that results can be seen faster.
    const hot_step = b.step("hot", "Build/install only the module to be hot-reloaded.");
    hot_step.dependOn(&install_work_mod.step);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}

