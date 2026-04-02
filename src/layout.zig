const std = @import("std");
const abi = @import("abi.zig");
const draw = @import("draw.zig");
const text = @import("text.zig");
const themes = @import("themes.zig");

pub const Cursor = struct {
    x: f32,
    y_top: f32,
    y_min: f32,
    width: f32,
    gap: f32 = 6.0,

    pub fn fromPanel(panel: draw.Rect, header_height: f32, padding: f32, gap: f32) Cursor {
        return .{
            .x = panel.x + padding,
            .y_top = panel.top() - header_height - padding,
            .y_min = panel.y + padding,
            .width = @max(panel.w - 2.0 * padding, 0.0),
            .gap = gap,
        };
    }

    pub fn tryTake(self: *Cursor, height: f32) ?f32 {
        if (height < 0.0) return null;
        if (self.y_top - height < self.y_min) return null;
        const y = self.y_top;
        self.y_top -= height + self.gap;
        return y;
    }

    pub fn take(self: *Cursor, height: f32) f32 {
        return self.tryTake(height) orelse self.y_min;
    }

    pub fn skip(self: *Cursor, amount: f32) void {
        self.y_top -= amount;
    }
};

pub fn fitText(buffer: []u8, message: []const u8, max_width: f32, options: text.Options) []const u8 {
    if (message.len == 0 or max_width <= 0.0) return "";
    if (text.measure(message, options).width <= max_width) return message;

    const ellipsis = "...";
    if (text.measure(ellipsis, options).width > max_width) return "";

    const max_keep = if (buffer.len > ellipsis.len) @min(message.len, buffer.len - ellipsis.len) else 0;

    var keep = max_keep;
    while (keep > 0) : (keep -= 1) {
        std.mem.copyForwards(u8, buffer[0..keep], message[0..keep]);
        std.mem.copyForwards(u8, buffer[keep .. keep + ellipsis.len], ellipsis);
        const candidate = buffer[0 .. keep + ellipsis.len];
        if (text.measure(candidate, options).width <= max_width) return candidate;
    }

    return ellipsis;
}

pub fn title(
    frame: *abi.Frame,
    cursor: *Cursor,
    label: []const u8,
    theme: themes.Theme,
    options: text.Options,
) void {
    var fitted_buf: [128]u8 = undefined;
    const fitted = fitText(&fitted_buf, label, cursor.width, options);
    if (fitted.len == 0) return;

    const h = text.measure(fitted, options).height;
    const y = cursor.tryTake(h) orelse return;
    text.drawTopLeft(frame, cursor.x, y, fitted, options, theme.text);
}

pub fn labelValue(
    frame: *abi.Frame,
    cursor: *Cursor,
    label: []const u8,
    value: []const u8,
    theme: themes.Theme,
    label_options: text.Options,
    value_options: text.Options,
) void {
    const min_gap: f32 = 10.0;
    if (cursor.width <= 0.0) return;

    const label_budget = @max(cursor.width * 0.45, 0.0);
    const value_budget = @max(cursor.width - label_budget - min_gap, 0.0);

    var label_buf: [128]u8 = undefined;
    var value_buf: [128]u8 = undefined;

    const fitted_label = fitText(&label_buf, label, label_budget, label_options);
    const fitted_value = fitText(&value_buf, value, value_budget, value_options);

    if (fitted_label.len == 0 and fitted_value.len == 0) return;

    const label_size = if (fitted_label.len > 0) text.measure(fitted_label, label_options) else text.Size{ .width = 0.0, .height = 0.0 };
    const value_size = if (fitted_value.len > 0) text.measure(fitted_value, value_options) else text.Size{ .width = 0.0, .height = 0.0 };
    const h = @max(label_size.height, value_size.height);
    const y = cursor.tryTake(h) orelse return;

    if (fitted_label.len > 0) {
        text.drawTopLeft(frame, cursor.x, y, fitted_label, label_options, theme.text_muted);
    }

    if (fitted_value.len > 0) {
        const value_x = cursor.x + @max(cursor.width - value_size.width, 0.0);
        text.drawTopLeft(frame, value_x, y, fitted_value, value_options, theme.text);
    }
}

pub fn separator(frame: *abi.Frame, cursor: *Cursor, theme: themes.Theme) void {
    const y = (cursor.tryTake(1.0) orelse return) - 1.0;
    draw.line(frame, cursor.x, y, cursor.x + cursor.width, y, 1.0, theme.panel_border);
    cursor.skip(2.0);
}

pub fn note(
    frame: *abi.Frame,
    cursor: *Cursor,
    message: []const u8,
    color: u32,
    options: text.Options,
) void {
    var fitted_buf: [192]u8 = undefined;
    const fitted = fitText(&fitted_buf, message, cursor.width, options);
    if (fitted.len == 0) return;

    const size = text.measure(fitted, options);
    const y = cursor.tryTake(size.height) orelse return;
    text.drawTopLeft(frame, cursor.x, y, fitted, options, color);
}

pub fn progressBar(
    frame: *abi.Frame,
    cursor: *Cursor,
    theme: themes.Theme,
    progress_01: f32,
    height: f32,
) void {
    const y = cursor.tryTake(height) orelse return;
    const bar = draw.rect(cursor.x, y - height, cursor.width, height);
    draw.fillRect(frame, bar, theme.panel_bg_hover);
    draw.strokeRect(frame, bar, 1.0, theme.panel_border);

    const p = @min(@max(progress_01, 0.0), 1.0);
    draw.fillRect(frame, .{
        .x = bar.x + 1.0,
        .y = bar.y + 1.0,
        .w = @max((bar.w - 2.0) * p, 0.0),
        .h = @max(bar.h - 2.0, 0.0),
    }, theme.accent);
}

