const std = @import("std");

pub const Options = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

pub fn standardOptions(b: *std.Build) Options {
    return .{
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    };
}

pub fn addHotModule(
    b: *std.Build,
    name: []const u8,
    root_source_file: std.Build.LazyPath,
    options: Options,
) *std.Build.Step.Compile {
    return b.addLibrary(.{
        .name = name,
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = root_source_file,
            .target = options.target,
            .optimize = options.optimize,
        }),
    });
}

pub fn addWin32Executable(
    b: *std.Build,
    name: []const u8,
    root_source_file: std.Build.LazyPath,
    options: Options,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = root_source_file,
            .target = options.target,
            .optimize = options.optimize,
        }),
    });

    exe.linkSystemLibrary("user32");
    exe.linkSystemLibrary("gdi32");

    return exe;
}

pub fn installArtifacts(b: *std.Build, artifacts: []const *std.Build.Step.Compile) void {
    for (artifacts) |artifact| {
        b.installArtifact(artifact);
    }
}

pub fn addHotStep(
    b: *std.Build,
    name: []const u8,
    description: []const u8,
    artifact: *std.Build.Step.Compile,
) void {
    const install_artifact = b.addInstallArtifact(artifact, .{});
    const step = b.step(name, description);
    step.dependOn(&install_artifact.step);
}

pub fn addRunInstalledArtifact(
    b: *std.Build,
    artifact: *std.Build.Step.Compile,
    step_name: []const u8,
    step_description: []const u8,
) void {
    const run_step = b.step(step_name, step_description);
    const run_cmd = b.addRunArtifact(artifact);
    run_cmd.step.dependOn(b.getInstallStep());
    run_step.dependOn(&run_cmd.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}

