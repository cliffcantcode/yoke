const std = @import("std");
const bs = @import("build_support.zig");

pub fn build(b: *std.Build) void {
    const options = bs.standardOptions(b);

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

    const artifacts = [_]*std.Build.Step.Compile{ work_mod, exe };
    bs.installArtifacts(b, artifacts[0..]);
    bs.addHotStep(b, "hot", "Build/install only work_module.", work_mod);
    bs.addRunInstalledArtifact(b, exe, "run", "Run yoke_win32.");
}

