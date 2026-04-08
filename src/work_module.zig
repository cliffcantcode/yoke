const std = @import("std");

const abi = @import("abi.zig");
const work = @import("work_runtime.zig");
const draw = @import("draw.zig");
const layout = @import("layout.zig");
const theme = @import("themes.zig").default;

const tau: f32 = 2.0 * std.math.pi;

const ContentMode = enum {
    timeline,
    table,
};

// Edit these values as though this were your own project code.
// Yoke should stay out of the way and give you a fast edit -> reload -> inspect loop.
const knobs = struct {
    const default_content_mode: ContentMode = .table;

    // Shared geometry
    const margin_px: f32 = 28.0;

    // Timeline demo
    const amplitude_px: f32 = 110.0;
    const baseline_y_01: f32 = 0.5; // 0 = bottom of plot, 1 = top of plot
    const baseline_offset_px: f32 = 0.0;
    const cycles_across_plot: f32 = 1.75;
    const phase_radians: f32 = 0.0;
    const animation_hz: f32 = 0.24;
    const line_thickness_px: f32 = 1.0;
    const sample_count: u32 = 256;
    const vertical_divisions: u32 = 3;
    const show_grid: bool = false;
    const show_amplitude_guides: bool = true;
    const show_sample_points: bool = false;
    const sample_marker_every: u32 = 16;

    // Table demo
    const table_text_scale: f32 = 2.0;
    const table_padding_px: f32 = 16.0;
    const table_column_gap_px: f32 = 18.0;
    const table_row_gap_px: f32 = 8.0;
};

pub const App = struct {
    time_sec: f32 = 0.0,
    content_mode: ContentMode = knobs.default_content_mode,

    pub fn onReload(self: *App, memory: *work.PlatformMemory) void {
        _ = memory;
        self.time_sec = 0.0;
        self.content_mode = knobs.default_content_mode;
    }

    pub fn update(self: *App, memory: *work.PlatformMemory, ctx: work.TickContext) void {
        _ = memory;

        if (abi.buttonPressed(ctx.input.space)) {
            self.content_mode = switch (self.content_mode) {
                .timeline => .table,
                .table => .timeline,
            };
        }

        if (abi.buttonPressed(ctx.input.escape)) {
            self.time_sec = 0.0;
            self.content_mode = knobs.default_content_mode;
        }

        self.time_sec += nsToSec(ctx.dt_ns);
    }

    pub fn render(self: *App, memory: *work.PlatformMemory, ctx: work.TickContext, frame: *work.Frame) void {
        _ = memory;
        _ = ctx;

        const body = draw.frameInnerRect(frame, knobs.margin_px);
        if (body.w <= 2.0 or body.h <= 2.0) return;

        switch (self.content_mode) {
            .timeline => drawWaveDemo(self, frame, body),
            .table => drawTableDemo(frame, body),
        }
    }
};

const sample_columns = [_]layout.TableColumn{
    .{ .header = "FIELD", .weight = 2.4 },
    .{ .header = "TYPE", .weight = 1.2 },
    .{ .header = "VALUE", .weight = 2.0 },
    .{ .header = "NOTES", .weight = 3.4 },
};

const sample_rows = [_][sample_columns.len][]const u8{
    .{ "patient_id", "string", "PT-10427", "stable join key from intake" },
    .{ "encounter_ts", "datetime", "2025-04-06 08:12", "timezone normalized to local" },
    .{ "heart_rate", "u16", "78", "raw device sample from room monitor" },
    .{ "bp_systolic", "u16", "118", "latest validated observation" },
    .{ "bp_diastolic", "u16", "74", "paired with systolic sample" },
    .{ "note_excerpt", "text", "follow-up requested after discharge", "truncated with ellipsis if narrow" },
};

fn nsToSec(ns: u64) f32 {
    return @as(f32, @floatFromInt(ns)) / @as(f32, @floatFromInt(std.time.ns_per_s));
}

fn drawTableDemo(frame: *work.Frame, body: draw.Rect) void {
    var table = layout.Table(sample_columns.len).init(
        frame,
        body,
        theme,
        .{ .scale = knobs.table_text_scale },
        sample_columns,
        .{
            .padding = knobs.table_padding_px,
            .column_gap = knobs.table_column_gap_px,
            .row_gap = knobs.table_row_gap_px,
            .border_color = theme.panel_border,
            .header_color = theme.accent,
            .cell_color = theme.text,
            .rule_color = theme.panel_border,
        },
    );

    for (sample_rows) |row| {
        if (!table.row(row)) break;
    }
}

fn drawWaveDemo(self: *const App, frame: *work.Frame, plot: draw.Rect) void {
    const baseline_y = plot.y + plot.h * knobs.baseline_y_01 + knobs.baseline_offset_px;
    const baseline_y_01 = if (plot.h > 0.0)
        (baseline_y - plot.y) / plot.h
    else
        0.0;
    const phase = knobs.phase_radians + self.time_sec * tau * knobs.animation_hz;
    const amplitude_px = plotAmplitudePx(plot, baseline_y);
    const amplitude_y_01 = if (plot.h > 0.0)
        amplitude_px / plot.h
    else
        0.0;

    if (knobs.show_grid and knobs.vertical_divisions > 1) {
        var i: u32 = 1;
        while (i < knobs.vertical_divisions) : (i += 1) {
            const t = @as(f32, @floatFromInt(i)) /
                @as(f32, @floatFromInt(knobs.vertical_divisions));
            const gx = plot.x + plot.w * t;
            draw.line(frame, gx, plot.y, gx, plot.top(), 1.0, theme.panel_border);
        }
    }

    draw.line(frame, plot.x, baseline_y, plot.right(), baseline_y, 1.0, theme.panel_border);

    if (knobs.show_amplitude_guides) {
        draw.line(
            frame,
            plot.x,
            baseline_y + amplitude_px,
            plot.right(),
            baseline_y + amplitude_px,
            1.0,
            theme.panel_border,
        );
        draw.line(
            frame,
            plot.x,
            baseline_y - amplitude_px,
            plot.right(),
            baseline_y - amplitude_px,
            1.0,
            theme.panel_border,
        );
    }

    draw.drawTimeline(
        WaveTimelineContext,
        waveTimelineY01,
        frame,
        plot,
        .{
            .sample_count = @intCast(knobs.sample_count),
            .line_thickness = knobs.line_thickness_px,
            .line_color = theme.accent,
            .border_color = theme.panel_border,
            .marker_color = if (knobs.show_sample_points) theme.accent else null,
            .marker_size = if (knobs.show_sample_points) 3.0 else 0.0,
            .marker_every = if (knobs.show_sample_points) @intCast(knobs.sample_marker_every) else 0,
        },
        .{
            .baseline_y_01 = baseline_y_01,
            .amplitude_y_01 = amplitude_y_01,
            .phase = phase,
        },
    );
}

const WaveTimelineContext = struct {
    baseline_y_01: f32,
    amplitude_y_01: f32,
    phase: f32,
};

fn plotAmplitudePx(plot: draw.Rect, baseline_y: f32) f32 {
    const max_down = @max(baseline_y - plot.y - 1.0, 0.0);
    const max_up = @max(plot.top() - baseline_y - 1.0, 0.0);
    return @min(knobs.amplitude_px, @min(max_down, max_up));
}

fn waveTimelineY01(context: WaveTimelineContext, sample_index: usize, x_01: f32) f32 {
    _ = sample_index;
    const wave_phase = x_01 * knobs.cycles_across_plot * tau + context.phase;
    return context.baseline_y_01 + @sin(wave_phase) * context.amplitude_y_01;
}

const runtime = work.Runtime(App);

export fn yoke_get_api() callconv(.c) *const work.Api {
    return runtime.api();
}
