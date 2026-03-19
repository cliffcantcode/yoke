const std = @import("std");

const abi = @import("abi.zig");
const themes = @import("themes.zig");
const assert = @import("assert.zig");

pub const Theme = themes.Theme;

pub const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,

    pub fn right(self: Rect) f32 {
        assert.hard(self.w >= 0, "Rect.right requires non-negative width, got {d}", .{self.w});
        return self.x + self.w;
    }

    pub fn top(self: Rect) f32 {
        assert.hard(self.h >= 0, "Rect.height requires non-negative height, got {d}", .{self.h});
        return self.y + self.h;
    }
};

pub fn rect(x: f32, y: f32, w: f32, h: f32) Rect {
    assert.hard(w >= 0, "rect requires non-negative width, got {d}", .{w});
    assert.hard(h >= 0, "rect requires non-negative height, got {d}", .{h});
    return .{ .x = x, .y = y, .w = w, .h = h };
}

pub fn contains(r: Rect, px: f32, py: f32) bool {
    assert.hard(r.w >= 0, "contains requires non-negative rect width, got {d}", .{r.w});
    assert.hard(r.h >= 0, "contains requires non-negative rect height, got {d}", .{r.h});
    return px >= r.x and px < r.right() and py >= r.y and py < r.top();
}

pub fn begin(frame: *abi.Frame, theme: Theme) void {
    abi.clear(frame, theme.canvas_bg);
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

pub fn line(
    frame: *abi.Frame,
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
    thickness: f32,
    color: u32,
) void {
    abi.line(frame, x0, y0, x1, y1, thickness, color);
}

pub fn panel(frame: *abi.Frame, r: Rect, fill: u32, border: u32) void {
    fillRect(frame, r, fill);
    strokeRect(frame, r, 2, border);
}

pub fn cursorSquare(frame: *abi.Frame, x: f32, y: f32, color: u32) void {
    fillRect(frame, rect(x - 3, y - 3, 7, 7), color);
}

