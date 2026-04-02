const std = @import("std");

const abi = @import("abi.zig");
const canvas_fit = @import("canvas_fit.zig");
const draw = @import("draw.zig");
const layout = @import("layout.zig");
const text = @import("text.zig");
const themes = @import("themes.zig");
const widgets = @import("widgets.zig");

pub const telemetry_history_len: usize = 96;
pub const telemetry_panel_index: usize = 2;
pub const loop_panel_index: usize = 3;
pub const module_panel_index: usize = 4;
pub const panel_header_height: f32 = 28.0;
pub const panel_body_padding: f32 = 10.0;
pub const grid_padding: f32 = 24.0;
pub const grid_gap: f32 = 16.0;
pub const square_body_size: f32 = 320.0;
pub const timeline_body_height: f32 = square_body_size;

const timeline_body_width: f32 = square_body_size * 2.0 + grid_gap;

pub const TelemetrySeries = struct {
    samples_ms: [telemetry_history_len]f32 = [_]f32{0.0} ** telemetry_history_len,
    write_index: usize = 0,
    count: usize = 0,
    last_ms: f32 = 0.0,

    pub fn push(self: *@This(), sample_ms: f32) void {
        self.samples_ms[self.write_index] = sample_ms;
        self.write_index = (self.write_index + 1) % telemetry_history_len;
        if (self.count < telemetry_history_len) self.count += 1;
        self.last_ms = sample_ms;
    }

    fn oldestSlot(self: *const @This()) usize {
        return if (self.count < telemetry_history_len) 0 else self.write_index;
    }

    pub fn sampleOldestFirst(self: *const @This(), index: usize) f32 {
        if (index >= self.count) return 0.0;
        const slot = (self.oldestSlot() + index) % telemetry_history_len;
        return self.samples_ms[slot];
    }

    pub fn averageMs(self: *const @This()) f32 {
        if (self.count == 0) return 0.0;

        var accum: f32 = 0.0;
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            accum += self.sampleOldestFirst(i);
        }

        return accum / @as(f32, @floatFromInt(self.count));
    }

    pub fn maxMs(self: *const @This()) f32 {
        var max_ms: f32 = 0.0;
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            max_ms = @max(max_ms, self.sampleOldestFirst(i));
        }
        return max_ms;
    }
};

pub const Telemetry = struct {
    update: TelemetrySeries = .{},
    render: TelemetrySeries = .{},
    frame: TelemetrySeries = .{},
    last_render_command_count: u32 = 0,
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
    panels: [5]widgets.DraggablePanel = .{
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
        return bodyRectForPanel(self.panels[panel_index], panel_header_height);
    }

    pub fn moduleBodyRect(self: *const PanelGrid) draw.Rect {
        return self.panelBodyRect(module_panel_index);
    }

    pub fn updateLayout(self: *PanelGrid, client_width: u32, client_height: u32) !void {
        const available_w = @max(@as(f32, @floatFromInt(client_width)) - 2.0 * grid_padding, 0.0);
        const available_h = @max(@as(f32, @floatFromInt(client_height)) - 2.0 * grid_padding, 0.0);

        const square_size = @max(@min(
            @max((available_w - grid_gap) * 0.5, 0.0),
            @max((available_h - 2.0 * grid_gap) / 3.0, 0.0),
        ), 0.0);

        const top_grid_w = square_size * 2.0 + grid_gap;
        const used_h = square_size * 3.0 + 2.0 * grid_gap;

        const top_grid_x = grid_padding + @max((available_w - top_grid_w) * 0.5, 0.0);
        const base_y = grid_padding + @max((available_h - used_h) * 0.5, 0.0);

        const left_x = top_grid_x;
        const right_x = top_grid_x + square_size + grid_gap;
        const bottom_y = base_y;
        const middle_y = base_y + square_size + grid_gap;
        const top_y = middle_y + square_size + grid_gap;

        self.panels[0].dragging = false;
        self.panels[0].rect = draw.rect(left_x, top_y, square_size, square_size);

        self.panels[1].dragging = false;
        self.panels[1].rect = draw.rect(right_x, top_y, square_size, square_size);

        self.panels[2].dragging = false;
        self.panels[2].rect = draw.rect(left_x, middle_y, square_size, square_size);

        self.panels[3].dragging = false;
        self.panels[3].rect = draw.rect(right_x, middle_y, square_size, square_size);

        self.panels[4].dragging = false;
        self.panels[4].rect = draw.rect(grid_padding, bottom_y, available_w, square_size);
    }

    pub fn draw_grid(
        self: *const PanelGrid,
        frame: *abi.Frame,
        theme: themes.Theme,
        ctx: abi.TickContext,
        info: DashboardInfo,
    ) void {
        for (self.panels, 0..) |panel, panel_index| {
            panel.draw_panel(frame, theme, ctx, panel_header_height);
            drawPanelHeaderTitle(panel_index, panel, frame, theme, info, panel_header_height);
            drawPanelBody(panel_index, panel, frame, theme, info, panel_header_height);
        }
    }
};

fn panelTitle(panel_index: usize, info: DashboardInfo) []const u8 {
    return switch (panel_index) {
        0 => "YOKE STATUS",
        1 => "INPUT",
        2 => "TELEMETRY",
        3 => "LOOP",
        4 => info.module_name,
        else => unreachable,
    };
}

fn logicalBodyRectForPanel(panel_index: usize) draw.Rect {
    return switch (panel_index) {
        module_panel_index => draw.rect(0.0, 0.0, timeline_body_width, timeline_body_height),
        else => draw.rect(0.0, 0.0, square_body_size, square_body_size),
    };
}

fn bodyCursor(body: draw.Rect, gap: f32) layout.Cursor {
    return .{
        .x = body.x + panel_body_padding,
        .y_top = body.top() - panel_body_padding,
        .y_min = body.y + panel_body_padding,
        .width = @max(body.w - 2.0 * panel_body_padding, 0.0),
        .gap = gap,
    };
}

fn bodyRectForPanel(panel: widgets.DraggablePanel, header_height: f32) draw.Rect {
    const inner = draw.inset(panel.rect, panel_body_padding);
    return draw.rect(
        inner.x,
        inner.y,
        inner.w,
        @max(inner.h - header_height, 0.0),
    );
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
    small_opts: text.Options,
) void {
    var value_buf: [128]u8 = undefined;
    var ui = bodyCursor(body, 6.0);

    const reloads = std.fmt.bufPrint(&value_buf, "{d}", .{info.reload_count}) catch "?";
    layout.labelValue(frame, &ui, "Reloads", reloads, theme, body_opts, body_opts);

    const updates = std.fmt.bufPrint(&value_buf, "{d}", .{info.update_count}) catch "?";
    layout.labelValue(frame, &ui, "Updates", updates, theme, body_opts, body_opts);

    const renders = std.fmt.bufPrint(&value_buf, "{d}", .{info.render_count}) catch "?";
    layout.labelValue(frame, &ui, "Renders", renders, theme, body_opts, body_opts);

    layout.separator(frame, &ui, theme);
    layout.note(frame, &ui, info.module_name, theme.accent, small_opts);
    layout.note(frame, &ui, "Managed by Yoke.", theme.text_muted, small_opts);
}

fn drawInputBody(
    frame: *abi.Frame,
    body: draw.Rect,
    theme: themes.Theme,
    info: DashboardInfo,
    body_opts: text.Options,
    small_opts: text.Options,
) void {
    var value_buf: [128]u8 = undefined;
    var ui = bodyCursor(body, 6.0);

    const mouse_x = std.fmt.bufPrint(&value_buf, "{d:.1}", .{info.input.mouse_x}) catch "?";
    layout.labelValue(frame, &ui, "Mouse X", mouse_x, theme, body_opts, body_opts);

    const mouse_y = std.fmt.bufPrint(&value_buf, "{d:.1}", .{info.input.mouse_y}) catch "?";
    layout.labelValue(frame, &ui, "Mouse Y", mouse_y, theme, body_opts, body_opts);

    layout.labelValue(
        frame,
        &ui,
        "LMB",
        if (info.input.mouse_left.is_down != 0) "DOWN" else "UP",
        theme,
        body_opts,
        body_opts,
    );

    layout.separator(frame, &ui, theme);
    layout.note(
        frame,
        &ui,
        if (info.input.escape.is_down != 0) "ESC down" else "ESC up",
        theme.text_muted,
        small_opts,
    );
    layout.note(
        frame,
        &ui,
        if (info.input.space.is_down != 0) "SPACE down" else "SPACE up",
        theme.text_muted,
        small_opts,
    );
}

fn drawLoopBody(
    frame: *abi.Frame,
    body: draw.Rect,
    theme: themes.Theme,
    info: DashboardInfo,
    body_opts: text.Options,
    small_opts: text.Options,
) void {
    var value_buf: [128]u8 = undefined;
    var ui = bodyCursor(body, 6.0);

    const frame_last = std.fmt.bufPrint(&value_buf, "{d:.2} ms", .{info.telemetry.frame.last_ms}) catch "?";
    layout.labelValue(frame, &ui, "Frame last", frame_last, theme, body_opts, body_opts);

    const frame_avg = std.fmt.bufPrint(&value_buf, "{d:.2} ms", .{info.telemetry.frame.averageMs()}) catch "?";
    layout.labelValue(frame, &ui, "Frame avg", frame_avg, theme, body_opts, body_opts);

    const fps_ema = std.fmt.bufPrint(&value_buf, "{d:.1}", .{info.fps_ema}) catch "?";
    layout.labelValue(frame, &ui, "FPS EMA", fps_ema, theme, body_opts, body_opts);

    const target = std.fmt.bufPrint(&value_buf, "U{d} / R{d}", .{ info.update_hz, info.render_hz }) catch "?";
    layout.labelValue(frame, &ui, "Target", target, theme, body_opts, body_opts);

    layout.separator(frame, &ui, theme);
    layout.note(frame, &ui, "Wide timeline panel auto-fits content.", theme.accent, small_opts);
    layout.note(frame, &ui, "Edit and hot reload to watch telemetry move.", theme.text_muted, small_opts);
}

fn drawTelemetryBody(
    frame: *abi.Frame,
    body: draw.Rect,
    theme: themes.Theme,
    info: DashboardInfo,
    body_opts: text.Options,
    small_opts: text.Options,
) void {
    const plot = draw.rect(
        body.x + panel_body_padding,
        body.y + panel_body_padding,
        @max(body.w - 2.0 * panel_body_padding, 0.0),
        108.0,
    );

    var value_buf: [128]u8 = undefined;
    var ui = layout.Cursor{
        .x = body.x + panel_body_padding,
        .y_top = body.top() - panel_body_padding,
        .y_min = plot.top() + 12.0,
        .width = @max(body.w - 2.0 * panel_body_padding, 0.0),
        .gap = 6.0,
    };

    const update_last = std.fmt.bufPrint(&value_buf, "{d:.2} ms", .{info.telemetry.update.last_ms}) catch "?";
    layout.labelValue(frame, &ui, "Update last", update_last, theme, body_opts, body_opts);

    const update_avg = std.fmt.bufPrint(&value_buf, "{d:.2} ms", .{info.telemetry.update.averageMs()}) catch "?";
    layout.labelValue(frame, &ui, "Update avg", update_avg, theme, body_opts, body_opts);

    const update_max = std.fmt.bufPrint(&value_buf, "{d:.2} ms", .{info.telemetry.update.maxMs()}) catch "?";
    layout.labelValue(frame, &ui, "Update max", update_max, theme, body_opts, body_opts);

    const render_last = std.fmt.bufPrint(&value_buf, "{d:.2} ms", .{info.telemetry.render.last_ms}) catch "?";
    layout.labelValue(frame, &ui, "Render last", render_last, theme, body_opts, body_opts);

    const render_avg = std.fmt.bufPrint(&value_buf, "{d:.2} ms", .{info.telemetry.render.averageMs()}) catch "?";
    layout.labelValue(frame, &ui, "Render avg", render_avg, theme, body_opts, body_opts);

    const render_max = std.fmt.bufPrint(&value_buf, "{d:.2} ms", .{info.telemetry.render.maxMs()}) catch "?";
    layout.labelValue(frame, &ui, "Render max", render_max, theme, body_opts, body_opts);

    layout.separator(frame, &ui, theme);

    const cmd_count = std.fmt.bufPrint(&value_buf, "{d}", .{info.telemetry.last_render_command_count}) catch "?";
    layout.labelValue(frame, &ui, "Draw cmds", cmd_count, theme, small_opts, small_opts);
    layout.note(frame, &ui, info.module_name, theme.text_muted, small_opts);

    drawTelemetryHistory(frame, plot, theme, info);
}

fn drawTelemetryHistory(frame: *abi.Frame, plot: draw.Rect, theme: themes.Theme, info: DashboardInfo) void {
    if (plot.w <= 2.0 or plot.h <= 2.0) return;

    draw.fillRect(frame, plot, theme.panel_bg_hover);
    draw.strokeRect(frame, plot, 1.0, theme.panel_border);

    const budget_ms = 1000.0 / @as(f32, @floatFromInt(@max(info.render_hz, 1)));
    const plot_max_ms = @max(
        budget_ms * 1.25,
        @max(info.telemetry.update.maxMs(), info.telemetry.render.maxMs()) * 1.05,
    );

    if (plot_max_ms > 0.0 and budget_ms > 0.0) {
        const guide_y = plot.y + @min(budget_ms / plot_max_ms, 1.0) * plot.h;
        draw.line(frame, plot.x, guide_y, plot.right(), guide_y, 1.0, theme.panel_border);
    }

    plotTelemetrySeries(frame, plot, &info.telemetry.update, plot_max_ms, theme.accent_hover);
    plotTelemetrySeries(frame, plot, &info.telemetry.render, plot_max_ms, theme.accent);
}

fn plotTelemetrySeries(
    frame: *abi.Frame,
    plot: draw.Rect,
    series: *const TelemetrySeries,
    plot_max_ms: f32,
    color: u32,
) void {
    if (series.count < 2 or plot_max_ms <= 0.0) return;

    var prev_x = plot.x;
    var prev_y = plot.y + @min(series.sampleOldestFirst(0) / plot_max_ms, 1.0) * plot.h;

    var i: usize = 1;
    while (i < series.count) : (i += 1) {
        const t = @as(f32, @floatFromInt(i)) /
            @as(f32, @floatFromInt(series.count - 1));
        const x = plot.x + plot.w * t;
        const y = plot.y + @min(series.sampleOldestFirst(i) / plot_max_ms, 1.0) * plot.h;
        draw.line(frame, prev_x, prev_y, x, y, 1.0, color);
        prev_x = x;
        prev_y = y;
    }
}

fn drawPanelBody(
    panel_index: usize,
    panel: widgets.DraggablePanel,
    frame: *abi.Frame,
    theme: themes.Theme,
    info: DashboardInfo,
    header_height: f32,
) void {
    if (panel_index == module_panel_index) return;

    const body_rect = bodyRectForPanel(panel, header_height);
    if (body_rect.w <= 0.0 or body_rect.h <= 0.0) return;

    const logical_body = logicalBodyRectForPanel(panel_index);
    const fit = canvas_fit.contain(logical_body.w, logical_body.h, body_rect);
    if (fit.scale <= 0.0) return;

    const cmd_start: usize = @intCast(frame.command_buffer.count);
    var logical_frame = abi.Frame{
        .target = .{
            .width = @max(@as(u32, @intFromFloat(logical_body.w)), 1),
            .height = @max(@as(u32, @intFromFloat(logical_body.h)), 1),
        },
        .command_buffer = frame.command_buffer,
    };

    draw.pushClipRect(&logical_frame, logical_body);

    const body_opts = text.Options{ .scale = 2.0 };
    const small_opts = text.Options{ .scale = 1.0 };

    switch (panel_index) {
        0 => drawStatusBody(&logical_frame, logical_body, theme, info, body_opts, small_opts),
        1 => drawInputBody(&logical_frame, logical_body, theme, info, body_opts, small_opts),
        telemetry_panel_index => drawTelemetryBody(&logical_frame, logical_body, theme, info, body_opts, small_opts),
        loop_panel_index => drawLoopBody(&logical_frame, logical_body, theme, info, body_opts, small_opts),
        else => unreachable,
    }

    draw.popClip(&logical_frame);

    const cmd_end: usize = @intCast(logical_frame.command_buffer.count);
    canvas_fit.transformCommandSlice(logical_frame.command_buffer.commands[cmd_start..cmd_end], fit);
    frame.command_buffer.count = logical_frame.command_buffer.count;
}

pub fn render(
    grid: *PanelGrid,
    frame: *abi.Frame,
    theme: themes.Theme,
    ctx: abi.TickContext,
    info: DashboardInfo,
) !void {
    try grid.updateLayout(ctx.input.client_width, ctx.input.client_height);
    grid.draw_grid(frame, theme, ctx, info);
}
