const std = @import("std");
const abi = @import("abi.zig");
const draw = @import("draw.zig");
const text = @import("text.zig");
const themes = @import("themes.zig");
const assert = @import("assert.zig");

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

pub const CellAlign = enum {
    left,
    right,
};

pub const TableColumn = struct {
    header: []const u8 = "",
    weight: f32 = 1.0,
    cell_align: CellAlign = .left,
};

pub const TableStyle = struct {
    padding: f32 = 0.0,
    column_gap: f32 = 14.0,
    row_gap: f32 = 8.0,
    background_color: ?u32 = null,
    border_color: ?u32 = null,
    header_color: ?u32 = null,
    cell_color: ?u32 = null,
    rule_color: ?u32 = null,
    draw_header_rule: bool = true,
};

fn tableRowHeight(options: text.Options) f32 {
    return text.glyphHeight(options);
}

fn drawTableCell(
    frame: *abi.Frame,
    cell: draw.Rect,
    value: []const u8,
    options: text.Options,
    color: u32,
    cell_align: CellAlign,
) void {
    if (cell.w <= 0.0 or cell.h <= 0.0 or value.len == 0) return;

    var fitted_buf: [256]u8 = undefined;
    const fitted = fitText(&fitted_buf, value, cell.w, options);
    if (fitted.len == 0) return;

    const size = text.measure(fitted, options);
    const x = switch (cell_align) {
        .left => cell.x,
        .right => cell.x + @max(cell.w - size.width, 0.0),
    };
    text.drawTopLeft(frame, x, cell.top(), fitted, options, color);
}

pub fn Table(comptime column_count: usize) type {
    comptime {
        if (column_count == 0) @compileError("layout.Table requires at least one column");
    }

    return struct {
        frame: *abi.Frame,
        theme: themes.Theme,
        outer: draw.Rect,
        inner: draw.Rect,
        cursor: Cursor,
        options: text.Options,
        style: TableStyle,
        columns: [column_count]TableColumn,
        column_x: [column_count]f32,
        column_width: [column_count]f32,

        pub fn init(
            frame: *abi.Frame,
            outer: draw.Rect,
            theme: themes.Theme,
            options: text.Options,
            columns: [column_count]TableColumn,
            style: TableStyle,
        ) @This() {
            assert.is_finite(options.scale, "layout.Table.options.scale", .{});
            assert.hard(options.scale > 0.0, "layout.Table options.scale must be > 0, got {d}", .{options.scale});
            assert.is_finite(style.padding, "layout.Table.style.padding", .{});
            assert.is_finite(style.column_gap, "layout.Table.style.column_gap", .{});
            assert.is_finite(style.row_gap, "layout.Table.style.row_gap", .{});
            assert.hard(style.padding >= 0.0, "layout.Table padding must be >= 0, got {d}", .{style.padding});
            assert.hard(style.column_gap >= 0.0, "layout.Table column_gap must be >= 0, got {d}", .{style.column_gap});
            assert.hard(style.row_gap >= 0.0, "layout.Table row_gap must be >= 0, got {d}", .{style.row_gap});

            var inner = draw.inset(outer, style.padding);
            if (outer.w <= 0.0 or outer.h <= 0.0) {
                inner = draw.rect(outer.x, outer.y, 0.0, 0.0);
            }

            var self = @This(){
                .frame = frame,
                .theme = theme,
                .outer = outer,
                .inner = inner,
                .cursor = .{
                    .x = inner.x,
                    .y_top = inner.top(),
                    .y_min = inner.y,
                    .width = inner.w,
                    .gap = style.row_gap,
                },
                .options = options,
                .style = style,
                .columns = columns,
                .column_x = [_]f32{0.0} ** column_count,
                .column_width = [_]f32{0.0} ** column_count,
            };

            if (style.background_color) |background_color| {
                draw.fillRect(frame, outer, background_color);
            }
            if (style.border_color) |border_color| {
                draw.strokeRect(frame, outer, 1.0, border_color);
            }

            self.computeColumns();
            self.drawHeader();
            return self;
        }

        fn computeColumns(self: *@This()) void {
            if (self.inner.w <= 0.0) return;

            var total_weight: f32 = 0.0;
            for (self.columns, 0..) |column, index| {
                assert.is_finite(column.weight, "layout.Table.column.weight", .{});
                assert.hard(column.weight > 0.0, "layout.Table column {d} weight must be > 0, got {d}", .{ index, column.weight });
                total_weight += column.weight;
            }
            assert.hard(total_weight > 0.0, "layout.Table requires total column weight > 0", .{});

            const gap_count: usize = if (column_count > 0) column_count - 1 else 0;
            const total_gap = self.style.column_gap * @as(f32, @floatFromInt(gap_count));
            const usable_width = @max(self.inner.w - total_gap, 0.0);

            var x = self.inner.x;
            var i: usize = 0;
            while (i < column_count) : (i += 1) {
                self.column_x[i] = x;
                self.column_width[i] = if (i + 1 == column_count)
                    @max(self.inner.right() - x, 0.0)
                else
                    @max(usable_width * (self.columns[i].weight / total_weight), 0.0);
                x += self.column_width[i] + self.style.column_gap;
            }
        }

        fn drawHeader(self: *@This()) void {
            var has_header = false;
            for (self.columns) |column| {
                if (column.header.len > 0) {
                    has_header = true;
                    break;
                }
            }
            if (!has_header) return;

            const row_height = tableRowHeight(self.options);
            const y_top = self.cursor.tryTake(row_height) orelse return;
            const header_color = self.style.header_color orelse self.theme.text;

            var i: usize = 0;
            while (i < column_count) : (i += 1) {
                const cell = draw.rect(
                    self.column_x[i],
                    y_top - row_height,
                    self.column_width[i],
                    row_height,
                );
                drawTableCell(
                    self.frame,
                    cell,
                    self.columns[i].header,
                    self.options,
                    header_color,
                    self.columns[i].cell_align,
                );
            }

            if (self.style.draw_header_rule) {
                _ = self.separator();
            }
        }

        pub fn row(self: *@This(), values: [column_count][]const u8) bool {
            const row_height = tableRowHeight(self.options);
            const y_top = self.cursor.tryTake(row_height) orelse return false;
            const cell_color = self.style.cell_color orelse self.theme.text;

            var i: usize = 0;
            while (i < column_count) : (i += 1) {
                const cell = draw.rect(
                    self.column_x[i],
                    y_top - row_height,
                    self.column_width[i],
                    row_height,
                );
                drawTableCell(
                    self.frame,
                    cell,
                    values[i],
                    self.options,
                    cell_color,
                    self.columns[i].cell_align,
                );
            }

            return true;
        }

        pub fn separator(self: *@This()) bool {
            const y = (self.cursor.tryTake(1.0) orelse return false) - 1.0;
            const color = self.style.rule_color orelse self.theme.panel_border;
            draw.line(self.frame, self.inner.x, y, self.inner.right(), y, 1.0, color);
            self.cursor.skip(2.0);
            return true;
        }
    };
}

