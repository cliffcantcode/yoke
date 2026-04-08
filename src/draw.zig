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

    pub fn assertValid(self: Rect) void {
        assert.finite(self.x, "Rect.x");
        assert.finite(self.y, "Rect.y");
        assert.finite(self.w, "Rect.w");
        assert.finite(self.h, "Rect.h");
        assert.hard(self.w >= 0.0, "Rect.w must be >= 0, got {d}", .{self.w});
        assert.hard(self.h >= 0.0, "Rect.h must be >= 0, got {d}", .{self.h});
    }

    pub fn right(self: Rect) f32 {
        self.assertValid();
        return self.x + self.w;
    }

    pub fn top(self: Rect) f32 {
        self.assertValid();
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
    const r = Rect{ .x = x, .y = y, .w = w, .h = h };
    r.assertValid();
    return r;
}

pub fn frameRect(frame: *const abi.Frame) Rect {
    return rect(
        0.0,
        0.0,
        @as(f32, @floatFromInt(frame.target.width)),
        @as(f32, @floatFromInt(frame.target.height)),
    );
}

pub fn frameInnerRect(frame: *const abi.Frame, padding: f32) Rect {
    return inset(frameRect(frame), padding);
}

pub fn inset(r: Rect, amount: f32) Rect {
    r.assertValid();
    assert.finite(amount, "inset.amount");
    assert.hard(amount >= 0.0, "inset requires non-negative amount, got {d}", .{amount});

    const shrink = amount * 2.0;
    return rect(
        r.x + amount,
        r.y + amount,
        @max(r.w - shrink, 0.0),
        @max(r.h - shrink, 0.0),
    );
}

pub fn contains(r: Rect, px: f32, py: f32) bool {
    r.assertValid();
    assert.finite(px, "contains.px");
    assert.finite(py, "contains.py");
    return px >= r.x and px < r.right() and py >= r.y and py < r.top();
}

pub fn begin(frame: *abi.Frame, theme: Theme) void {
    abi.clear(frame, theme.canvas_bg);
}

pub fn originMarker(frame: *abi.Frame, theme: Theme) void {
    abi.fillRect(frame, 0, 0, 16, 16, theme.origin_marker);
}

pub fn fillRect(frame: *abi.Frame, r: Rect, color: u32) void {
    r.assertValid();
    if (r.w <= 0.0 or r.h <= 0.0) return;
    abi.fillRect(frame, r.x, r.y, r.right(), r.top(), color);
}

pub fn strokeRect(frame: *abi.Frame, r: Rect, thickness: f32, color: u32) void {
    r.assertValid();
    assert.finite(thickness, "strokeRect.thickness");
    assert.hard(thickness >= 0.0, "strokeRect thickness must be >= 0, got {d}", .{thickness});
    if (r.w <= 0.0 or r.h <= 0.0 or thickness <= 0.0) return;
    abi.strokeRect(frame, r.x, r.y, r.right(), r.top(), thickness, color);
}

fn quantizeRect(r: Rect) IntRect {
    r.assertValid();
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
    assert.finite(x0, "line.x0");
    assert.finite(y0, "line.y0");
    assert.finite(x1, "line.x1");
    assert.finite(y1, "line.y1");
    assert.finite(thickness, "line.thickness");
    assert.hard(thickness >= 0.0, "line thickness must be >= 0, got {d}", .{thickness});
    if (thickness <= 0.0) return;
    abi.line(frame, x0, y0, x1, y1, thickness, color);
}

pub const TimelineOptions = struct {
    sample_count: usize,
    line_thickness: f32 = 1.0,
    line_color: u32,
    background_color: ?u32 = null,
    border_color: ?u32 = null,
    marker_color: ?u32 = null,
    marker_size: f32 = 0.0,
    marker_every: usize = 0,

    pub fn assertValid(self: @This()) void {
        assert.finite(self.line_thickness, "TimelineOptions.line_thickness");
        assert.hard(self.line_thickness >= 0.0, "TimelineOptions.line_thickness must be >= 0, got {d}", .{self.line_thickness});
        assert.finite(self.marker_size, "TimelineOptions.marker_size");
        assert.hard(self.marker_size >= 0.0, "TimelineOptions.marker_size must be >= 0, got {d}", .{self.marker_size});
        if (self.marker_color != null and self.marker_size > 0.0) {
            assert.hard(self.marker_every > 0, "TimelineOptions marker drawing requires marker_every > 0", .{});
        }
    }
};

pub fn timelineY(plot: Rect, y_01: f32) f32 {
    plot.assertValid();
    assert.finite(y_01, "timelineY.y_01");
    return plot.y + std.math.clamp(y_01, 0.0, 1.0) * plot.h;
}

fn timelineSampleX(plot: Rect, last_sample_index: usize, sample_index: usize) f32 {
    if (last_sample_index == 0) return plot.x;
    return plot.x + plot.w * (@as(f32, @floatFromInt(sample_index)) /
        @as(f32, @floatFromInt(last_sample_index)));
}

fn drawTimelineMarker(frame: *abi.Frame, x: f32, y: f32, size: f32, color: u32) void {
    if (size <= 0.0) return;

    const half = size * 0.5;
    fillRect(frame, rect(x - half, y - half, size, size), color);
}

fn shouldDrawTimelineMarker(options: TimelineOptions, sample_index: usize) bool {
    return options.marker_color != null and
        options.marker_size > 0.0 and
        options.marker_every > 0 and
        (sample_index % options.marker_every == 0 or sample_index + 1 == options.sample_count);
}

fn timelineSampleY(
    comptime Context: type,
    comptime sampleY01Fn: fn (Context, usize, f32) f32,
    plot: Rect,
    context: Context,
    sample_index: usize,
    x_01: f32,
) f32 {
    const y_01 = sampleY01Fn(context, sample_index, x_01);
    assert.finite(y_01, "drawTimeline.sample_y_01");
    return timelineY(plot, y_01);
}

pub fn drawTimeline(
    comptime Context: type,
    comptime sampleY01Fn: fn (Context, usize, f32) f32,
    frame: *abi.Frame,
    plot: Rect,
    options: TimelineOptions,
    context: Context,
) void {
    plot.assertValid();
    options.assertValid();

    if (options.background_color) |background_color| fillRect(frame, plot, background_color);
    if (options.border_color) |border_color| strokeRect(frame, plot, 1.0, border_color);
    if (plot.w <= 0.0 or plot.h <= 0.0 or options.sample_count < 2) return;

    const last_sample_index = options.sample_count - 1;
    var prev_x = plot.x;
    var prev_y = timelineSampleY(Context, sampleY01Fn, plot, context, 0, 0.0);

    if (shouldDrawTimelineMarker(options, 0)) {
        drawTimelineMarker(frame, prev_x, prev_y, options.marker_size, options.marker_color.?);
    }

    var sample_index: usize = 1;
    while (sample_index < options.sample_count) : (sample_index += 1) {
        const x_01 = @as(f32, @floatFromInt(sample_index)) /
            @as(f32, @floatFromInt(last_sample_index));
        const x = timelineSampleX(plot, last_sample_index, sample_index);
        const y = timelineSampleY(Context, sampleY01Fn, plot, context, sample_index, x_01);

        line(frame, prev_x, prev_y, x, y, options.line_thickness, options.line_color);
        if (shouldDrawTimelineMarker(options, sample_index)) {
            drawTimelineMarker(frame, x, y, options.marker_size, options.marker_color.?);
        }

        prev_x = x;
        prev_y = y;
    }
}

pub fn pushClipRect(frame: *abi.Frame, r: Rect) void {
    r.assertValid();
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
