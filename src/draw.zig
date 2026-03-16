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

pub fn cursor(frame: *abi.Frame, x: f32, y: f32, color: u32) void {
    abi.fillRect(frame, x - 3, y - 3, x + 4, y + 4, color);
}

