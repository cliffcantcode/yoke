const std = @import("std");

pub inline fn is_finite(float: f32, comptime fmt: []const u8, args: anytype) void {
    if (!std.math.isFinite(float)) std.debug.panic(fmt, args);
}

pub inline fn hard(ok: bool, comptime fmt: []const u8, args: anytype) void {
    if (!ok) std.debug.panic(fmt, args);
}

