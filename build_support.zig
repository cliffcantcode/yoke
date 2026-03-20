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

pub const TracyOptions = struct {
    enable: bool,
    callstack_depth: i32,
    on_demand: bool,
    only_localhost: bool,
    delayed_init: bool,
    manual_lifetime: bool,
};

pub fn makeTracyOptions(b: *std.Build) TracyOptions {
    return .{
        .enable = b.option(bool, "tracy", "Enable Tracy profiling") orelse false,

        .callstack_depth = 0,
        .on_demand = false,
        .only_localhost = true,
        .delayed_init = true,
        .manual_lifetime = true,
    };
}

pub fn validateTracyOptions(tracy: TracyOptions) void {
    if (tracy.callstack_depth < 0) {
        @panic("tracy.callstack_depth must be >= 0");
    }

    if (tracy.manual_lifetime and !tracy.delayed_init) {
        @panic("tracy.manual_lifetime requires tracy.delayed_init");
    }
}

pub fn addTracyBuildOptionsModule(b: *std.Build, tracy: TracyOptions) *std.Build.Step.Options {
    const options = b.addOptions();
    options.addOption(bool, "tracy_enable", tracy.enable);
    options.addOption(i32, "tracy_callstack_depth", tracy.callstack_depth);
    options.addOption(bool, "tracy_manual_lifetime", tracy.manual_lifetime);
    return options;
}

pub fn attachTracyBuildOptions(compile: *std.Build.Step.Compile, options: *std.Build.Step.Options) void {
    compile.root_module.addOptions("build_options", options);
}

fn addTracyDefine(compile: *std.Build.Step.Compile, name: []const u8, value: ?[]const u8) void {
    compile.root_module.addCMacro(name, value orelse "1");
}

pub fn addTracyRuntimeLibrary(
    b: *std.Build,
    options: Options,
    tracy: TracyOptions,
) ?*std.Build.Step.Compile {
    if (!tracy.enable) return null;

    const lib = b.addLibrary(.{
        .name = "yoke_tracy",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tracy_runtime_root.zig"),
            .target = options.target,
            .optimize = options.optimize,
        }),
    });

    lib.linkLibC();
    lib.linkLibCpp();

    lib.addIncludePath(b.path("third_party/tracy/public"));

    // Tracy third-party source: silence its Windows/clang format diagnostics locally.
    lib.addCSourceFile(.{
        .file = b.path("third_party/tracy/public/TracyClient.cpp"),
        .flags = &.{
            "-std=c++11",
            "-Wno-format",
        },
    });

    lib.addCSourceFile(.{
        .file = b.path("src/tracy_shim.cpp"),
        .flags = &.{
            "-std=c++11",
        },
    });

    addTracyDefine(lib, "TRACY_ENABLE", null);

    if (tracy.callstack_depth > 0) {
        const depth = b.fmt("{d}", .{tracy.callstack_depth});
        addTracyDefine(lib, "TRACY_CALLSTACK", depth);
    }

    if (tracy.on_demand) {
        addTracyDefine(lib, "TRACY_ON_DEMAND", null);
    }

    if (tracy.only_localhost) {
        addTracyDefine(lib, "TRACY_ONLY_LOCALHOST", null);
    }

    // Compile-first defaults for Windows+Clang right now.
    addTracyDefine(lib, "TRACY_NO_CONTEXT_SWITCH", null);
    addTracyDefine(lib, "TRACY_NO_SYSTEM_TRACING", null);

    if (tracy.delayed_init) {
        addTracyDefine(lib, "TRACY_DELAYED_INIT", null);
    }

    if (tracy.manual_lifetime) {
        addTracyDefine(lib, "TRACY_MANUAL_LIFETIME", null);
    }

    if (options.target.result.os.tag == .windows) {
        lib.linkSystemLibrary("ws2_32");
        lib.linkSystemLibrary("dbghelp");
        lib.linkSystemLibrary("secur32");
    }

    return lib;
}

pub fn linkTracyRuntime(compile: *std.Build.Step.Compile, tracy_runtime: ?*std.Build.Step.Compile) void {
    if (tracy_runtime) |lib| {
        compile.linkLibrary(lib);
    }
}

