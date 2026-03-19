const std = @import("std");
const bs = @import("build_support.zig");

pub fn build(b: *std.Build) void {
    const options = bs.standardOptions(b);

    const tracy = bs.makeTracyOptions(b);
    bs.validateTracyOptions(tracy);

    const tracy_build_options = bs.addTracyBuildOptionsModule(b, tracy);

    const work_mod = bs.addHotModule(
        b,
        "work_module",
        b.path("src/work_module.zig"),
        options,
    );

    const exe = bs.addWin32Executable(
        b,
        "yoke_win32",
        b.path("src/yoke_win32.zig"),
        options,
    );

    bs.attachTracyBuildOptions(work_mod, tracy_build_options);
    bs.attachTracyBuildOptions(exe, tracy_build_options);

    const tracy_runtime = bs.addTracyRuntimeLibrary(b, options, tracy);
    bs.linkTracyRuntime(exe, tracy_runtime);
    bs.linkTracyRuntime(work_mod, tracy_runtime);

    const core_artifacts = [_]*std.Build.Step.Compile{ work_mod, exe };
    bs.installArtifacts(b, core_artifacts[0..]);
    if (tracy_runtime) |lib| {
        b.installArtifact(lib);
    }

    bs.addHotStep(b, "hot", "Build/install only work_module.", work_mod);
    bs.addRunInstalledArtifact(b, exe, "run", "Run yoke_win32.");
}

