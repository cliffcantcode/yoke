const std = @import("std");
const math = @import("math.zig");

pub inline fn is_finite(float: f32, comptime fmt: []const u8, args: anytype) void {
    if (!std.math.isFinite(float)) std.debug.panic(fmt, args);
}

pub inline fn hard(ok: bool, comptime fmt: []const u8, args: anytype) void {
    if (!ok) std.debug.panic(fmt, args);
}

pub const FrameRateEmaGuard = struct {
    max_avg_hz: f64,
    target_floor_ema_frame_ns: f64,
    warmup_frames: u32,
    consecutive_violation_limit: u32,

    ema_frame_ns: math.ExponentialMovingAverage,
    sample_count: u32 = 0,
    violation_streak: u32 = 0,

    pub const ns_per_s_f64: f64 = @floatFromInt(std.time.ns_per_s);
    pub const ns_per_ms_f64: f64 = @floatFromInt(std.time.ns_per_ms);

    pub fn init(target_hz: f64) @This() {
        const tolerance_hz = 0.25;
        const max_avg_hz = target_hz + tolerance_hz;

        return .{
            .max_avg_hz = max_avg_hz,
            .target_floor_ema_frame_ns = ns_per_s_f64 / max_avg_hz,
            .warmup_frames = 120,
            .consecutive_violation_limit = 60,
            .ema_frame_ns = math.ExponentialMovingAverage.init(0.05),
        };
    }

    pub fn pushFrameNs(self: *@This(), frame_ns: u64) void {
        const sample_ns = @as(f64, @floatFromInt(frame_ns));
        const ema_frame_ns = self.ema_frame_ns.push(sample_ns);

        self.sample_count += 1;

        if (self.sample_count < self.warmup_frames) return;

        if (ema_frame_ns < self.target_floor_ema_frame_ns) {
            self.violation_streak += 1;

            if (self.violation_streak >= self.consecutive_violation_limit) {
                std.debug.panic(
                    "frame rate exceeded target for too long: ema_fps={d:.3}, max_avg_fps={d:.3}, ema_frame_ms={d:.3}, streak={d}",
                    .{
                        self.emaFps(),
                        self.max_avg_hz,
                        self.emaFrameMs(),
                        self.violation_streak,
                    },
                );
            }
        } else {
            self.violation_streak = 0;
        }
    }

    pub fn emaFps(self: *const @This()) f64 {
        const ema_frame_ns = self.ema_frame_ns.value() orelse return 0.0;
        return ns_per_s_f64 / ema_frame_ns;
    }

    pub fn emaFrameMs(self: *const @This()) f64 {
        const ema_frame_ns = self.ema_frame_ns.value() orelse return 0.0;
        return ema_frame_ns / ns_per_ms_f64;
    }
};

