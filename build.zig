const std = @import("std");
const bs = @import("build_support.zig");

pub fn build(b: *std.Build) void {
    const options = bs.standardOptions(b);

    const tracy = bs.makeTracyOptions(b);
    bs.applyTracyBuildMode(b, tracy);
    bs.validateTracyOptions(tracy);

    const hot_reload_enable = !tracy.enable;
    const build_options = bs.addBuildOptionsModule(b, tracy, hot_reload_enable);

    const exe = bs.addWin32Executable(
        b,
        "yoke_win32",
        b.path("src/yoke_win32.zig"),
        options,
    );
    bs.attachBuildOptions(exe, build_options);

    const tracy_runtime = bs.addTracyRuntimeLibrary(b, options, tracy);
    bs.linkTracyRuntime(exe, tracy_runtime);

    if (hot_reload_enable) {
        const work_mod = bs.addHotModule(
            b,
            "work_module",
            b.path("src/work_module.zig"),
            options,
        );
        bs.attachBuildOptions(work_mod, build_options);

        const core_artifacts = [_]*std.Build.Step.Compile{ work_mod, exe };
        bs.installArtifacts(b, core_artifacts[0..]);
        bs.addHotStep(b, "hot", "Build/install only work_module.", work_mod);
    } else {
        const work_mod = bs.addStaticModule(
            b,
            "work_module",
            b.path("src/work_module.zig"),
            options,
        );
        bs.attachBuildOptions(work_mod, build_options);
        exe.linkLibrary(work_mod);

        const core_artifacts = [_]*std.Build.Step.Compile{exe};
        bs.installArtifacts(b, core_artifacts[0..]);
    }

    bs.addRunInstalledArtifact(b, exe, "run", "Run yoke_win32.");
}

