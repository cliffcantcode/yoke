const std = @import("std");
const abi = @import("abi.zig");
const themes = @import("themes.zig");

pub const Theme = themes.Theme;

pub const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,

    pub fn right(self: Rect) f32 {
        return self.x + self.w;
    }

    pub fn top(self: Rect) f32 {
        return self.y + self.h;
    }
};

pub fn rect(x: f32, y: f32, w: f32, h: f32) Rect {
    return .{ .x = x, .y = y, .w = w, .h = h };
}

pub fn contains(r: Rect, px: f32, py: f32) bool {
    return px >= r.x and px < r.right() and py >= r.y and py < r.top();
}

pub fn begin(frame: *abi.Frame, theme: Theme) void {
    abi.clear(frame, theme.canvas_bg);
    abi.setCursor(frame, .arrow);
}

pub fn originMarker(frame: *abi.Frame, theme: Theme) void {
    abi.fillRect(frame, 0, 0, 16, 16, theme.origin_marker);
}

pub fn fillRect(frame: *abi.Frame, r: Rect, color: u32) void {
    abi.fillRect(frame, r.x, r.y, r.right(), r.top(), color);
}

pub fn strokeRect(frame: *abi.Frame, r: Rect, thickness: f32, color: u32) void {
    abi.strokeRect(frame, r.x, r.y, r.right(), r.top(), thickness, color);
}

pub fn panel(frame: *abi.Frame, r: Rect, fill: u32, border: u32) void {
    fillRect(frame, r, fill);
    strokeRect(frame, r, 2, border);
}

pub fn orbitSquares(
    frame: *abi.Frame,
    center_x: f32,
    center_y: f32,
    tick_index: u64,
    radius: f32,
    square_size: f32,
    color: u32,
) void {
    const t = @as(f32, @floatFromInt(tick_index)) * 0.18;
    const tau_over_4: f32 = std.math.tau / 4.0;

    var i: u32 = 0;
    while (i < 4) : (i += 1) {
        const angle = t + @as(f32, @floatFromInt(i)) * tau_over_4;
        const x = center_x + std.math.cos(angle) * radius;
        const y = center_y + std.math.sin(angle) * radius;
        const half = square_size * 0.5;

        abi.fillRect(frame, x - half, y - half, x + half, y + half, color);
    }
}

