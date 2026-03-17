const abi = @import("abi.zig");
const draw = @import("draw.zig");
const text = @import("text.zig");
const themes = @import("themes.zig");

pub const Cursor = struct {
    x: f32,
    y_top: f32,
    width: f32,
    gap: f32 = 6.0,

    pub fn fromPanel(panel: draw.Rect, header_height: f32, padding: f32, gap: f32) Cursor {
        return .{
            .x = panel.x + padding,
            .y_top = panel.top() - header_height - padding,
            .width = @max(panel.w - 2.0 * padding, 0.0),
            .gap = gap,
        };
    }

    pub fn take(self: *Cursor, height: f32) f32 {
        const y = self.y_top;
        self.y_top -= height + self.gap;
        return y;
    }

    pub fn skip(self: *Cursor, amount: f32) void {
        self.y_top -= amount;
    }
};

pub fn title(
    frame: *abi.Frame,
    cursor: *Cursor,
    label: []const u8,
    theme: themes.Theme,
    options: text.Options,
) void {
    const h = text.measure(label, options).height;
    const y = cursor.take(h);
    text.drawTopLeft(frame, cursor.x, y, label, options, theme.text);
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
    const label_size = text.measure(label, label_options);
    const value_size = text.measure(value, value_options);
    const h = @max(label_size.height, value_size.height);
    const y = cursor.take(h);

    text.drawTopLeft(frame, cursor.x, y, label, label_options, theme.text_muted);

    const value_x = cursor.x + @max(cursor.width - value_size.width, 0.0);
    text.drawTopLeft(frame, value_x, y, value, value_options, theme.text);
}

pub fn separator(frame: *abi.Frame, cursor: *Cursor, theme: themes.Theme) void {
    const y = cursor.take(1.0) - 1.0;
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
    const size = text.measure(message, options);
    const y = cursor.take(size.height);
    text.drawTopLeft(frame, cursor.x, y, message, options, color);
}

pub fn progressBar(
    frame: *abi.Frame,
    cursor: *Cursor,
    theme: themes.Theme,
    progress_01: f32,
    height: f32,
) void {
    const y = cursor.take(height);
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

