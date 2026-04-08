const std = @import("std");

const abi = @import("abi.zig");
const assert = @import("assert.zig");
const draw = @import("draw.zig");
const layout = @import("layout.zig");
const text = @import("text.zig");
const themes = @import("themes.zig");
const widgets = @import("widgets.zig");

pub const telemetry_history_len: usize = 96;
pub const status_panel_index: usize = 0;
pub const input_panel_index: usize = 1;
pub const telemetry_panel_index: usize = 2;
pub const loop_panel_index: usize = 3;
pub const module_panel_index: usize = 4;
pub const panel_count: usize = module_panel_index + 1;
pub const panel_header_height: f32 = 28.0;
pub const panel_body_padding: f32 = 10.0;
pub const grid_padding: f32 = 24.0;
pub const grid_gap: f32 = 16.0;
pub const square_body_size: f32 = 320.0;
pub const timeline_body_height: f32 = square_body_size;

comptime {
    if (telemetry_history_len < 2) @compileError("telemetry_history_len must be >= 2");
    if (panel_count != 5) @compileError("PanelGrid expects 5 panels.");
    if (status_panel_index != 0 or input_panel_index != 1 or telemetry_panel_index != 2 or loop_panel_index != 3 or module_panel_index != 4) {
        @compileError("PanelGrid panel indices must stay in layout order.");
    }
    if (module_panel_index != panel_count - 1) @compileError("module panel must stay last.");
    if (panel_header_height < 0.0 or panel_body_padding < 0.0 or grid_padding < 0.0 or grid_gap < 0.0) {
        @compileError("panel layout constants must be non-negative");
    }
    if (timeline_body_height <= 0.0) @compileError("timeline_body_height must be positive");
}

pub const TelemetrySeries = struct {
    samples_ms: [telemetry_history_len]f32 = [_]f32{0.0} ** telemetry_history_len,
    write_index: usize = 0,
    count: usize = 0,
    last_ms: f32 = 0.0,

    pub const Stats = struct {
        last_ms: f32,
        avg_ms: f32,
        median_ms: f32,
        max_ms: f32,
    };

    pub fn assertValid(self: *const @This()) void {
        assert.hard(
            self.write_index < telemetry_history_len,
            "TelemetrySeries.write_index out of range: {d} >= {d}",
            .{ self.write_index, telemetry_history_len },
        );
        assert.hard(
            self.count <= telemetry_history_len,
            "TelemetrySeries.count out of range: {d} > {d}",
            .{ self.count, telemetry_history_len },
        );
        assert.finite(self.last_ms, "TelemetrySeries.last_ms");
        assert.hard(self.last_ms >= 0.0, "TelemetrySeries.last_ms must be >= 0, got {d}", .{self.last_ms});
    }

    pub fn push(self: *@This(), sample_ms: f32) void {
        self.assertValid();
        assert.finite(sample_ms, "TelemetrySeries.push.sample_ms");
        assert.hard(sample_ms >= 0.0, "TelemetrySeries.push requires non-negative sample_ms, got {d}", .{sample_ms});

        self.samples_ms[self.write_index] = sample_ms;
        self.write_index = (self.write_index + 1) % telemetry_history_len;
        if (self.count < telemetry_history_len) self.count += 1;
        self.last_ms = sample_ms;

        self.assertValid();
    }

    fn oldestSlot(self: *const @This()) usize {
        self.assertValid();
        return if (self.count == telemetry_history_len) self.write_index else 0;
    }

    pub fn sampleOldestFirst(self: *const @This(), index: usize) f32 {
        self.assertValid();
        assert.hard(
            index < self.count,
            "TelemetrySeries.sampleOldestFirst index out of range: {d} >= {d}",
            .{ index, self.count },
        );

        const slot = (self.oldestSlot() + index) % telemetry_history_len;
        const sample_ms = self.samples_ms[slot];
        assert.finite(sample_ms, "TelemetrySeries.sampleOldestFirst.sample_ms");
        assert.hard(sample_ms >= 0.0, "TelemetrySeries sample must be >= 0, got {d}", .{sample_ms});
        return sample_ms;
    }

    pub fn stats(self: *const @This()) Stats {
        self.assertValid();
        if (self.count == 0) {
            return .{ .last_ms = 0.0, .avg_ms = 0.0, .median_ms = 0.0, .max_ms = 0.0 };
        }

        var sorted: [telemetry_history_len]f32 = undefined;
        var accum: f32 = 0.0;
        var max_ms: f32 = 0.0;

        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            const sample_ms = self.sampleOldestFirst(i);
            sorted[i] = sample_ms;
            accum += sample_ms;
            max_ms = @max(max_ms, sample_ms);
        }

        i = 1;
        while (i < self.count) : (i += 1) {
            const value = sorted[i];
            var j = i;
            while (j > 0 and sorted[j - 1] > value) : (j -= 1) {
                sorted[j] = sorted[j - 1];
            }
            sorted[j] = value;
        }

        const mid = self.count / 2;
        const median_ms = if ((self.count & 1) == 1)
            sorted[mid]
        else
            (sorted[mid - 1] + sorted[mid]) * @as(f32, 0.5);

        return .{
            .last_ms = self.last_ms,
            .avg_ms = accum / @as(f32, @floatFromInt(self.count)),
            .median_ms = median_ms,
            .max_ms = max_ms,
        };
    }

};

pub const Telemetry = struct {
    update: TelemetrySeries = .{},
    render: TelemetrySeries = .{},
    frame: TelemetrySeries = .{},
    last_render_command_count: u32 = 0,

    pub fn assertValid(self: *const @This()) void {
        self.update.assertValid();
        self.render.assertValid();
        self.frame.assertValid();
    }
};

pub const DashboardInfo = struct {
    module_name: []const u8,
    telemetry: *const Telemetry,
    update_count: u64,
    render_count: u64,
    reload_count: u32,
    update_hz: u32,
    render_hz: u32,
    fps_ema: f32,
    input: abi.Input,
};

pub const PanelGrid = struct {
    panels: [panel_count]widgets.DraggablePanel = .{
        widgets.DraggablePanel.init(0, 0, 100, 100),
        widgets.DraggablePanel.init(0, 0, 100, 100),
        widgets.DraggablePanel.init(0, 0, 100, 100),
        widgets.DraggablePanel.init(0, 0, 100, 100),
        widgets.DraggablePanel.init(0, 0, 100, 100),
    },

    pub fn init(allocator: std.mem.Allocator) PanelGrid {
        _ = allocator;
        return .{};
    }

    pub fn deinit(self: *PanelGrid) void {
        _ = self;
    }

    pub fn panelBodyRect(self: *const PanelGrid, panel_index: usize) draw.Rect {
        assert.hard(panel_index < panel_count, "panel index {d} out of range", .{panel_index});
        return bodyRectForPanel(self.panels[panel_index], panel_header_height);
    }

    pub fn moduleBodyRect(self: *const PanelGrid) draw.Rect {
        return self.panelBodyRect(module_panel_index);
    }

    pub fn updateLayout(self: *PanelGrid, client_width: u32, client_height: u32) !void {
        const available_w = @max(@as(f32, @floatFromInt(client_width)) - 2.0 * grid_padding, 0.0);
        const available_h = @max(@as(f32, @floatFromInt(client_height)) - 2.0 * grid_padding, 0.0);

        const cell_w = @max((available_w - grid_gap) * 0.5, 0.0);
        const cell_h = @max((available_h - 2.0 * grid_gap) / 3.0, 0.0);

        const left_x = grid_padding;
        const right_x = left_x + cell_w + grid_gap;
        const bottom_y = grid_padding;
        const middle_y = bottom_y + cell_h + grid_gap;
        const top_y = middle_y + cell_h + grid_gap;

        const rects = [panel_count]draw.Rect{
            draw.rect(left_x, top_y, cell_w, cell_h),
            draw.rect(right_x, top_y, cell_w, cell_h),
            draw.rect(left_x, middle_y, cell_w, cell_h),
            draw.rect(right_x, middle_y, cell_w, cell_h),
            draw.rect(grid_padding, bottom_y, available_w, cell_h),
        };

        for (&self.panels, rects) |*panel, rect| {
            panel.dragging = false;
            panel.rect = rect;
        }
    }

    pub fn draw_grid(
        self: *const PanelGrid,
        frame: *abi.Frame,
        theme: themes.Theme,
        ctx: abi.TickContext,
        info: DashboardInfo,
    ) void {
        assertValidDashboardInfo(info);

        for (self.panels, 0..) |panel, panel_index| {
            panel.draw_panel(frame, theme, ctx, panel_header_height);
            drawPanelHeaderTitle(panel_index, panel, frame, theme, info, panel_header_height);
            drawPanelBody(panel_index, panel, frame, theme, info, panel_header_height);
        }
    }
};

fn assertValidDashboardInfo(info: DashboardInfo) void {
    assert.hard(info.module_name.len > 0, "DashboardInfo.module_name must not be empty", .{});
    info.telemetry.assertValid();
    assert.hard(info.update_hz > 0, "DashboardInfo.update_hz must be > 0", .{});
    assert.hard(info.render_hz > 0, "DashboardInfo.render_hz must be > 0", .{});
    assert.finite(info.fps_ema, "DashboardInfo.fps_ema");
    assert.hard(info.fps_ema >= 0.0, "DashboardInfo.fps_ema must be >= 0, got {d}", .{info.fps_ema});
    assert.finite(info.input.mouse_x, "DashboardInfo.input.mouse_x");
    assert.finite(info.input.mouse_y, "DashboardInfo.input.mouse_y");
}

fn panelTitle(panel_index: usize, info: DashboardInfo) []const u8 {
    return switch (panel_index) {
        status_panel_index => "YOKE STATUS",
        input_panel_index => "INPUT",
        telemetry_panel_index => "TELEMETRY",
        loop_panel_index => "LOOP",
        module_panel_index => info.module_name,
        else => unreachable,
    };
}

pub fn logicalBodyForRect(body: draw.Rect, logical_height: f32) draw.Rect {
    body.assertValid();
    assert.finite(logical_height, "logicalBodyForRect.logical_height");
    assert.hard(logical_height > 0.0, "logicalBodyForRect.logical_height must be > 0, got {d}", .{logical_height});

    const logical_width = if (body.h > 0.0)
        logical_height * body.w / body.h
    else
        logical_height;

    return draw.rect(0.0, 0.0, @max(logical_width, 0.0), logical_height);
}

fn bodyCursor(body: draw.Rect, gap: f32) layout.Cursor {
    body.assertValid();
    assert.finite(gap, "bodyCursor.gap");
    assert.hard(gap >= 0.0, "bodyCursor.gap must be >= 0, got {d}", .{gap});

    return .{
        .x = body.x + panel_body_padding,
        .y_top = body.top() - panel_body_padding,
        .y_min = body.y + panel_body_padding,
        .width = bodyInnerWidth(body),
        .gap = gap,
    };
}

fn bodyRectForPanel(panel: widgets.DraggablePanel, header_height: f32) draw.Rect {
    assert.finite(header_height, "bodyRectForPanel.header_height");
    assert.hard(header_height >= 0.0, "bodyRectForPanel.header_height must be >= 0, got {d}", .{header_height});

    const inner = draw.inset(panel.rect, panel_body_padding);
    return draw.rect(inner.x, inner.y, inner.w, @max(inner.h - header_height, 0.0));
}

fn bodyInnerWidth(body: draw.Rect) f32 {
    body.assertValid();
    return @max(body.w - 2.0 * panel_body_padding, 0.0);
}

fn bodyInnerHeight(body: draw.Rect) f32 {
    body.assertValid();
    return @max(body.h - 2.0 * panel_body_padding, 0.0);
}

fn dashboardBodyOptions(body: draw.Rect) text.Options {
    body.assertValid();
    const inner_w = bodyInnerWidth(body);
    const inner_h = bodyInnerHeight(body);

    const width_factor = inner_w / @as(f32, 520.0);
    const height_factor = inner_h / @as(f32, 220.0);
    const factor = @min(width_factor, height_factor);
    const scale = @max(@min(factor * @as(f32, 1.8), @as(f32, 2.0)), @as(f32, 1.0));

    return .{ .scale = scale };
}

fn dashboardRowGap(options: text.Options) f32 {
    assert.finite(options.scale, "dashboardRowGap.options.scale");
    return @max(@min(options.scale * @as(f32, 2.5), @as(f32, 6.0)), @as(f32, 4.0));
}

fn rowHeight(options: text.Options, gap: f32) f32 {
    assert.finite(options.scale, "rowHeight.options.scale");
    assert.finite(gap, "rowHeight.gap");
    assert.hard(gap >= 0.0, "rowHeight.gap must be >= 0, got {d}", .{gap});
    return text.glyphHeight(options) + gap;
}

fn canFitRows(body: draw.Rect, options: text.Options, gap: f32, rows: usize, extra_height: f32) bool {
    body.assertValid();
    assert.finite(gap, "canFitRows.gap");
    assert.finite(extra_height, "canFitRows.extra_height");
    assert.hard(gap >= 0.0, "canFitRows.gap must be >= 0, got {d}", .{gap});
    assert.hard(extra_height >= 0.0, "canFitRows.extra_height must be >= 0, got {d}", .{extra_height});

    const rows_f = @as(f32, @floatFromInt(rows));
    return bodyInnerHeight(body) >= rows_f * rowHeight(options, gap) + extra_height;
}

fn dashboardLabelValue(
    frame: *abi.Frame,
    ui: *layout.Cursor,
    label: []const u8,
    value: []const u8,
    theme: themes.Theme,
    options: text.Options,
) void {
    layout.labelValue(frame, ui, label, value, theme, options, options);
}

fn fmtBuf(buffer: []u8, comptime fmt: []const u8, args: anytype) []const u8 {
    return std.fmt.bufPrint(buffer, fmt, args) catch "?";
}

fn buttonState(button: abi.Button) []const u8 {
    return if (button.is_down != 0) "DOWN" else "UP";
}

const TimeUnit = struct {
    ms_per_unit: f32,
    suffix: []const u8,
};

const TelemetryPlotScale = struct {
    unit: TimeUnit,
    top_ms: f32,
};

fn chooseTimeUnit(max_ms: f32) TimeUnit {
    assert.finite(max_ms, "chooseTimeUnit.max_ms");
    const abs_ms = @abs(max_ms);
    if (abs_ms == 0.0) return .{ .ms_per_unit = 1.0, .suffix = "ms" };
    if (abs_ms >= 1000.0) return .{ .ms_per_unit = 1000.0, .suffix = "s" };
    if (abs_ms >= 1.0) return .{ .ms_per_unit = 1.0, .suffix = "ms" };
    if (abs_ms >= 0.001) return .{ .ms_per_unit = 0.001, .suffix = "us" };
    return .{ .ms_per_unit = 0.000001, .suffix = "ns" };
}

fn decimalsForVisibleDigits(value: f32) u8 {
    const abs_value = @abs(value);
    if (abs_value >= 1000.0) return 0;
    if (abs_value >= 100.0) return 1;
    if (abs_value >= 10.0) return 2;
    if (abs_value >= 1.0) return 3;
    return 4;
}

fn formatDuration(buffer: []u8, value_ms: f32, unit: TimeUnit) []const u8 {
    assert.finite(value_ms, "formatDuration.value_ms");
    assert.finite(unit.ms_per_unit, "formatDuration.unit.ms_per_unit");
    assert.hard(unit.ms_per_unit > 0.0, "formatDuration.unit.ms_per_unit must be > 0, got {d}", .{unit.ms_per_unit});

    const value = value_ms / unit.ms_per_unit;

    return switch (decimalsForVisibleDigits(value)) {
        0 => std.fmt.bufPrint(buffer, "{d:.0} {s}", .{ value, unit.suffix }) catch "?",
        1 => std.fmt.bufPrint(buffer, "{d:.1} {s}", .{ value, unit.suffix }) catch "?",
        2 => std.fmt.bufPrint(buffer, "{d:.2} {s}", .{ value, unit.suffix }) catch "?",
        3 => std.fmt.bufPrint(buffer, "{d:.3} {s}", .{ value, unit.suffix }) catch "?",
        else => std.fmt.bufPrint(buffer, "{d:.4} {s}", .{ value, unit.suffix }) catch "?",
    };
}

fn niceUpperBound(value: f32) f32 {
    assert.finite(value, "niceUpperBound.value");
    if (value <= 0.0) return 1.0;

    var normalized: f32 = value;
    var scale: f32 = 1.0;

    while (normalized > @as(f32, 10.0)) : (scale *= @as(f32, 10.0)) {
        normalized /= @as(f32, 10.0);
    }

    while (normalized < @as(f32, 1.0)) : (scale /= @as(f32, 10.0)) {
        normalized *= @as(f32, 10.0);
    }

    const nice: f32 = if (normalized <= @as(f32, 1.0))
        @as(f32, 1.0)
    else if (normalized <= @as(f32, 2.5))
        @as(f32, 2.5)
    else if (normalized <= @as(f32, 5.0))
        @as(f32, 5.0)
    else
        @as(f32, 10.0);

    return nice * scale;
}

fn choosePlotScale(peak_ms: f32) TelemetryPlotScale {
    assert.finite(peak_ms, "choosePlotScale.peak_ms");
    assert.hard(peak_ms >= 0.0, "choosePlotScale.peak_ms must be >= 0, got {d}", .{peak_ms});

    const padded_ms = @max(peak_ms * 1.15, 0.0);
    const unit = chooseTimeUnit(padded_ms);
    const top_units = niceUpperBound(@max(padded_ms / unit.ms_per_unit, 1.0));

    return .{
        .unit = unit,
        .top_ms = top_units * unit.ms_per_unit,
    };
}

fn drawPanelHeaderTitle(
    panel_index: usize,
    panel: widgets.DraggablePanel,
    frame: *abi.Frame,
    theme: themes.Theme,
    info: DashboardInfo,
    header_height: f32,
) void {
    const header_rect = panel.headerRect(header_height);
    if (header_rect.w <= 0 or header_rect.h <= 0) return;

    draw.pushClipRect(frame, header_rect);
    defer draw.popClip(frame);

    const title = panelTitle(panel_index, info);
    const options = text.Options{ .scale = 1.0 };
    const horizontal_padding: f32 = 8.0;

    var fitted_buf: [128]u8 = undefined;
    const fitted = layout.fitText(
        &fitted_buf,
        title,
        @max(header_rect.w - 2.0 * horizontal_padding, 0.0),
        options,
    );
    if (fitted.len == 0) return;

    const size = text.measure(fitted, options);
    const x = header_rect.x + @max((header_rect.w - size.width) * 0.5, 0.0);
    const y_top = header_rect.y + @max((header_rect.h - size.height) * 0.5, 0.0) + size.height;
    text.drawTopLeft(frame, x, y_top, fitted, options, theme.panel_bg);
}

fn drawStatusBody(
    frame: *abi.Frame,
    body: draw.Rect,
    theme: themes.Theme,
    info: DashboardInfo,
    body_opts: text.Options,
) void {
    const gap = dashboardRowGap(body_opts);
    var value_buf: [128]u8 = undefined;
    var ui = bodyCursor(body, gap);

    const reloads = fmtBuf(&value_buf, "{d}", .{info.reload_count});
    dashboardLabelValue(frame, &ui, "Reloads", reloads, theme, body_opts);

    const updates = fmtBuf(&value_buf, "{d}", .{info.update_count});
    dashboardLabelValue(frame, &ui, "Updates", updates, theme, body_opts);

    const renders = fmtBuf(&value_buf, "{d}", .{info.render_count});
    dashboardLabelValue(frame, &ui, "Renders", renders, theme, body_opts);

    if (canFitRows(body, body_opts, gap, 5, 0.0)) {
        const update_hz = fmtBuf(&value_buf, "{d} Hz", .{info.update_hz});
        dashboardLabelValue(frame, &ui, "Update Hz", update_hz, theme, body_opts);

        const render_hz = fmtBuf(&value_buf, "{d} Hz", .{info.render_hz});
        dashboardLabelValue(frame, &ui, "Render Hz", render_hz, theme, body_opts);
    }
}

fn drawInputBody(
    frame: *abi.Frame,
    body: draw.Rect,
    theme: themes.Theme,
    info: DashboardInfo,
    body_opts: text.Options,
) void {
    const gap = dashboardRowGap(body_opts);
    var value_buf: [128]u8 = undefined;
    var ui = bodyCursor(body, gap);

    const mouse_x = fmtBuf(&value_buf, "{d:.1}", .{info.input.mouse_x});
    dashboardLabelValue(frame, &ui, "Mouse X", mouse_x, theme, body_opts);

    const mouse_y = fmtBuf(&value_buf, "{d:.1}", .{info.input.mouse_y});
    dashboardLabelValue(frame, &ui, "Mouse Y", mouse_y, theme, body_opts);

    dashboardLabelValue(frame, &ui, "LMB", buttonState(info.input.mouse_left), theme, body_opts);

    if (canFitRows(body, body_opts, gap, 5, 0.0)) {
        dashboardLabelValue(frame, &ui, "ESC", buttonState(info.input.escape), theme, body_opts);
        dashboardLabelValue(frame, &ui, "SPACE", buttonState(info.input.space), theme, body_opts);
    }
}

fn drawLoopBody(
    frame: *abi.Frame,
    body: draw.Rect,
    theme: themes.Theme,
    info: DashboardInfo,
    body_opts: text.Options,
) void {
    const gap = dashboardRowGap(body_opts);
    var value_buf: [128]u8 = undefined;
    var ui = bodyCursor(body, gap);

    const frame_stats = info.telemetry.frame.stats();
    const frame_peak_ms = @max(frame_stats.max_ms, @max(frame_stats.last_ms, frame_stats.avg_ms));
    const frame_unit = chooseTimeUnit(frame_peak_ms);

    const show_avg = canFitRows(body, body_opts, gap, 4, 0.0);

    const frame_last = formatDuration(&value_buf, frame_stats.last_ms, frame_unit);
    dashboardLabelValue(frame, &ui, "Frame last", frame_last, theme, body_opts);

    if (show_avg) {
        const frame_avg = formatDuration(&value_buf, frame_stats.avg_ms, frame_unit);
        dashboardLabelValue(frame, &ui, "Frame avg", frame_avg, theme, body_opts);
    }

    const fps_ema = fmtBuf(&value_buf, "{d:.1}", .{info.fps_ema});
    dashboardLabelValue(frame, &ui, "FPS EMA", fps_ema, theme, body_opts);

    const target = fmtBuf(&value_buf, "U{d} / R{d}", .{ info.update_hz, info.render_hz });
    dashboardLabelValue(frame, &ui, "Target", target, theme, body_opts);
}

fn drawTelemetryBody(
    frame: *abi.Frame,
    body: draw.Rect,
    theme: themes.Theme,
    info: DashboardInfo,
    body_opts: text.Options,
) void {
    const gap = dashboardRowGap(body_opts);
    const update_stats = info.telemetry.update.stats();
    const update_peak_ms = @max(
        update_stats.max_ms,
        @max(update_stats.last_ms, @max(update_stats.avg_ms, update_stats.median_ms)),
    );
    const plot_scale = choosePlotScale(update_peak_ms);
    const telemetry_unit = plot_scale.unit;

    const stat_rows: usize = 4;
    const stat_height = @as(f32, @floatFromInt(stat_rows)) * rowHeight(body_opts, gap);
    const plot_overhead: f32 = 9.0 + 12.0;
    const available_plot_h = bodyInnerHeight(body) - stat_height - plot_overhead;
    const show_plot = available_plot_h >= 56.0;

    const plot = if (show_plot)
        draw.rect(
            body.x + panel_body_padding,
            body.y + panel_body_padding,
            bodyInnerWidth(body),
            available_plot_h,
        )
    else
        draw.rect(body.x, body.y, 0.0, 0.0);

    var ui = if (show_plot)
        layout.Cursor{
            .x = body.x + panel_body_padding,
            .y_top = body.top() - panel_body_padding,
            .y_min = plot.top() + 12.0,
            .width = bodyInnerWidth(body),
            .gap = gap,
        }
    else
        bodyCursor(body, gap);

    var value_buf: [128]u8 = undefined;

    const update_last = formatDuration(&value_buf, update_stats.last_ms, telemetry_unit);
    dashboardLabelValue(frame, &ui, "Update last", update_last, theme, body_opts);

    const update_avg = formatDuration(&value_buf, update_stats.avg_ms, telemetry_unit);
    dashboardLabelValue(frame, &ui, "Update avg", update_avg, theme, body_opts);

    const update_median = formatDuration(&value_buf, update_stats.median_ms, telemetry_unit);
    dashboardLabelValue(frame, &ui, "Update median", update_median, theme, body_opts);

    const update_max = formatDuration(&value_buf, update_stats.max_ms, telemetry_unit);
    dashboardLabelValue(frame, &ui, "Update max", update_max, theme, body_opts);

    if (show_plot) {
        layout.separator(frame, &ui, theme);
        drawTelemetryHistory(frame, plot, theme, info, plot_scale);
    }
}

const TelemetryTimelineContext = struct {
    series: *const TelemetrySeries,
    plot_max_ms: f32,
};

fn telemetryTimelineY01(context: TelemetryTimelineContext, sample_index: usize, x_01: f32) f32 {
    _ = x_01;
    assert.finite(context.plot_max_ms, "telemetryTimelineY01.plot_max_ms");
    if (context.plot_max_ms <= 0.0) return 0.0;
    return context.series.sampleOldestFirst(sample_index) / context.plot_max_ms;
}

fn drawTelemetryHistory(
    frame: *abi.Frame,
    plot: draw.Rect,
    theme: themes.Theme,
    info: DashboardInfo,
    plot_scale: TelemetryPlotScale,
) void {
    if (plot.w <= 2.0 or plot.h <= 2.0) return;

    draw.fillRect(frame, plot, theme.panel_bg_hover);
    draw.strokeRect(frame, plot, 1.0, theme.panel_border);

    const budget_ms = 1000.0 / @as(f32, @floatFromInt(@max(info.update_hz, 1)));
    const plot_max_ms = plot_scale.top_ms;
    assert.hard(plot_max_ms > 0.0, "drawTelemetryHistory.plot_max_ms must be > 0, got {d}", .{plot_max_ms});

    if (budget_ms > 0.0 and budget_ms <= plot_max_ms) {
        const guide_y = draw.timelineY(plot, budget_ms / plot_max_ms);
        draw.line(frame, plot.x, guide_y, plot.right(), guide_y, 1.0, theme.panel_border);
    }

    draw.drawTimeline(
        TelemetryTimelineContext,
        telemetryTimelineY01,
        frame,
        plot,
        .{
            .sample_count = info.telemetry.update.count,
            .line_thickness = 1.0,
            .line_color = theme.accent,
        },
        .{
            .series = &info.telemetry.update,
            .plot_max_ms = plot_max_ms,
        },
    );
}

fn drawPanelBody(
    panel_index: usize,
    panel: widgets.DraggablePanel,
    frame: *abi.Frame,
    theme: themes.Theme,
    info: DashboardInfo,
    header_height: f32,
) void {
    assert.hard(panel_index < panel_count, "panel index {d} out of range", .{panel_index});
    if (panel_index == module_panel_index) return;

    const body_rect = bodyRectForPanel(panel, header_height);
    if (body_rect.w <= 0.0 or body_rect.h <= 0.0) return;

    draw.pushClipRect(frame, body_rect);
    defer draw.popClip(frame);

    const body_opts = dashboardBodyOptions(body_rect);

    switch (panel_index) {
        status_panel_index => drawStatusBody(frame, body_rect, theme, info, body_opts),
        input_panel_index => drawInputBody(frame, body_rect, theme, info, body_opts),
        telemetry_panel_index => drawTelemetryBody(frame, body_rect, theme, info, body_opts),
        loop_panel_index => drawLoopBody(frame, body_rect, theme, info, body_opts),
        else => unreachable,
    }
}

pub fn render(
    grid: *PanelGrid,
    frame: *abi.Frame,
    theme: themes.Theme,
    ctx: abi.TickContext,
    info: DashboardInfo,
) !void {
    assertValidDashboardInfo(info);
    try grid.updateLayout(ctx.input.client_width, ctx.input.client_height);
    grid.draw_grid(frame, theme, ctx, info);
}
