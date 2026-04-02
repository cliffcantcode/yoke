const std = @import("std");

const abi = @import("abi.zig");
const themes = @import("themes.zig");
const assert = @import("assert.zig");

pub const Theme = themes.Theme;

pub const panel_corner_radius: f32 = 8.0;
pub const panel_border_thickness: f32 = 2.0;

pub const RoundedCorners = struct {
    top_left: bool = true,
    top_right: bool = true,
    bottom_right: bool = true,
    bottom_left: bool = true,

    pub const all = RoundedCorners{};
    pub const top = RoundedCorners{
        .bottom_right = false,
        .bottom_left = false,
    };
    pub const bottom = RoundedCorners{
        .top_left = false,
        .top_right = false,
    };
    pub const left = RoundedCorners{
        .top_right = false,
        .bottom_right = false,
    };
    pub const right = RoundedCorners{
        .top_left = false,
        .bottom_left = false,
    };
};

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

const IntRect = struct {
    x0: i32,
    y0: i32,
    x1: i32,
    y1: i32,

    fn width(self: IntRect) i32 {
        return self.x1 - self.x0;
    }

    fn height(self: IntRect) i32 {
        return self.y1 - self.y0;
    }

    fn isEmpty(self: IntRect) bool {
        return self.x0 >= self.x1 or self.y0 >= self.y1;
    }
};

const RowInsets = struct {
    left: i32,
    right: i32,
};

pub fn rect(x: f32, y: f32, w: f32, h: f32) Rect {
    assert.hard(w >= 0, "rect requires non-negative width, got {d}", .{w});
    assert.hard(h >= 0, "rect requires non-negative height, got {d}", .{h});
    return .{ .x = x, .y = y, .w = w, .h = h };
}

pub fn inset(r: Rect, amount: f32) Rect {
    assert.hard(amount >= 0, "inset requires non-negative amount, got {d}", .{amount});
    const shrink = amount * 2.0;
    return rect(
        r.x + amount,
        r.y + amount,
        @max(r.w - shrink, 0.0),
        @max(r.h - shrink, 0.0),
    );
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

fn quantizeRect(r: Rect) IntRect {
    return .{
        .x0 = @intFromFloat(r.x),
        .y0 = @intFromFloat(r.y),
        .x1 = @intFromFloat(r.right()),
        .y1 = @intFromFloat(r.top()),
    };
}

fn emitIntFillRect(frame: *abi.Frame, x0: i32, y0: i32, x1: i32, y1: i32, color: u32) void {
    if (x0 >= x1 or y0 >= y1) return;
    abi.fillRect(
        frame,
        @floatFromInt(x0),
        @floatFromInt(y0),
        @floatFromInt(x1),
        @floatFromInt(y1),
        color,
    );
}

fn clampedRadiusPx(ir: IntRect, requested_radius: f32) i32 {
    const max_radius_px = @divFloor(@min(ir.width(), ir.height()), 2);
    if (max_radius_px <= 0) return 0;

    const requested_px = @max(requested_radius, 0.0);
    const clamped = @min(requested_px, @as(f32, @floatFromInt(max_radius_px)));
    return @intFromFloat(@floor(clamped));
}

fn cornerInset(radius_px: i32, row_from_outer_edge: i32) i32 {
    if (radius_px <= 0) return 0;

    const r = @as(f32, @floatFromInt(radius_px));
    const y_center = @as(f32, @floatFromInt(row_from_outer_edge)) + 0.5;
    const dy = r - y_center;
    const x_extent = std.math.sqrt(@max(0.0, r * r - dy * dy));
    const inset_f = @ceil(r - x_extent - 0.5);

    return @intFromFloat(@max(inset_f, 0.0));
}

fn rowInsetsForRoundedRect(height_px: i32, radius_px: i32, corners: RoundedCorners, row_from_bottom: i32) RowInsets {
    var left: i32 = 0;
    var right: i32 = 0;

    if (radius_px > 0 and row_from_bottom < radius_px) {
        if (corners.bottom_left) left = @max(left, cornerInset(radius_px, row_from_bottom));
        if (corners.bottom_right) right = @max(right, cornerInset(radius_px, row_from_bottom));
    }

    const row_from_top = (height_px - 1) - row_from_bottom;
    if (radius_px > 0 and row_from_top < radius_px) {
        if (corners.top_left) left = @max(left, cornerInset(radius_px, row_from_top));
        if (corners.top_right) right = @max(right, cornerInset(radius_px, row_from_top));
    }

    return .{ .left = left, .right = right };
}

pub fn fillRoundedRect(
    frame: *abi.Frame,
    r: Rect,
    color: u32,
    radius: f32,
    corners: RoundedCorners,
) void {
    const ir = quantizeRect(r);
    if (ir.isEmpty()) return;

    const radius_px = clampedRadiusPx(ir, radius);
    if (radius_px <= 0) {
        emitIntFillRect(frame, ir.x0, ir.y0, ir.x1, ir.y1, color);
        return;
    }

    const h = ir.height();

    var run_start: i32 = 0;
    var current = rowInsetsForRoundedRect(h, radius_px, corners, 0);

    var row: i32 = 1;
    while (row < h) : (row += 1) {
        const next = rowInsetsForRoundedRect(h, radius_px, corners, row);
        if (next.left != current.left or next.right != current.right) {
            emitIntFillRect(
                frame,
                ir.x0 + current.left,
                ir.y0 + run_start,
                ir.x1 - current.right,
                ir.y0 + row,
                color,
            );
            run_start = row;
            current = next;
        }
    }

    emitIntFillRect(
        frame,
        ir.x0 + current.left,
        ir.y0 + run_start,
        ir.x1 - current.right,
        ir.y1,
        color,
    );
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


pub fn pushClipRect(frame: *abi.Frame, r: Rect) void {
    abi.pushClip(frame, r.x, r.y, r.right(), r.top());
}

pub fn popClip(frame: *abi.Frame) void {
    abi.popClip(frame);
}

pub fn panel(frame: *abi.Frame, r: Rect, fill: u32, border: u32) void {
    fillRoundedRect(frame, r, border, panel_corner_radius, RoundedCorners.all);

    const inner = inset(r, panel_border_thickness);
    if (inner.w <= 0 or inner.h <= 0) return;

    fillRoundedRect(
        frame,
        inner,
        fill,
        @max(panel_corner_radius - panel_border_thickness, 0.0),
        RoundedCorners.all,
    );
}

pub fn cursorSquare(frame: *abi.Frame, x: f32, y: f32, color: u32) void {
    fillRect(frame, rect(x - 3, y - 3, 7, 7), color);
}
