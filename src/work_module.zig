const std = @import("std");

const work = @import("work_runtime.zig");
const draw = @import("draw.zig");
const theme = @import("themes.zig").default;

const tau: f32 = 2.0 * std.math.pi;

// Edit these values as though this were your own project code.
// Yoke should stay out of the way and give you a fast edit -> reload -> inspect loop.
const knobs = struct {
    // Geometry
    const margin_px: f32 = 28;
    const amplitude_px: f32 = 110;
    const baseline_y_01: f32 = 0.5; // 0 = bottom of plot, 1 = top of plot
    const baseline_offset_px: f32 = 0.0;

    // Wave shape
    const cycles_across_plot: f32 = 1.75;
    const phase_radians: f32 = 0.0;
    const animation_hz: f32 = 0.24;
    const line_thickness_px: f32 = 1.0;

    // Sampling / guides
    const sample_count: u32 = 256;
    const vertical_divisions: u32 = 3;
    const show_grid: bool = false;
    const show_amplitude_guides: bool = true;
    const show_sample_points: bool = false;
    const sample_marker_every: u32 = 16;
};

pub const App = struct {
    time_sec: f32 = 0.0,
    paused: bool = false,

    pub fn onReload(self: *App, memory: *work.PlatformMemory) void {
        _ = memory;
        // Hot reload back to a known phase so visual changes are easy to compare.
        self.time_sec = 0.0;
    }

    pub fn update(self: *App, memory: *work.PlatformMemory, ctx: work.TickContext) void {
        _ = memory;

        if (ctx.input.space.changed != 0 and ctx.input.space.is_down != 0) {
            self.paused = !self.paused;
        }

        if (ctx.input.escape.changed != 0 and ctx.input.escape.is_down != 0) {
            self.time_sec = 0.0;
        }

        if (!self.paused) {
            self.time_sec += @as(f32, @floatFromInt(ctx.dt_ns)) /
                @as(f32, @floatFromInt(std.time.ns_per_s));
        }
    }

    pub fn render(self: *App, memory: *work.PlatformMemory, ctx: work.TickContext, frame: *work.Frame) void {
        _ = memory;
        _ = ctx;

        const width = @as(f32, @floatFromInt(frame.target.width));
        const height = @as(f32, @floatFromInt(frame.target.height));

        const plot = draw.rect(
            knobs.margin_px,
            knobs.margin_px,
            @max(width - knobs.margin_px * 2.0, 0.0),
            @max(height - knobs.margin_px * 2.0, 0.0),
        );
        if (plot.w <= 2.0 or plot.h <= 2.0) return;

        draw.strokeRect(frame, plot, 1.0, theme.panel_border);

        const baseline_y = plot.y + plot.h * knobs.baseline_y_01 + knobs.baseline_offset_px;
        const phase = knobs.phase_radians + self.time_sec * tau * knobs.animation_hz;
        const amplitude_px = plotAmplitudePx(plot, baseline_y);

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

        if (knobs.sample_count < 2) return;

        var prev_x = plot.x;
        var prev_y = sampleWaveY(0.0, baseline_y, phase, amplitude_px);

        var i: u32 = 1;
        while (i < knobs.sample_count) : (i += 1) {
            const t = @as(f32, @floatFromInt(i)) /
                @as(f32, @floatFromInt(knobs.sample_count - 1));
            const x = plot.x + plot.w * t;
            const y = sampleWaveY(t, baseline_y, phase, amplitude_px);

            draw.line(frame, prev_x, prev_y, x, y, knobs.line_thickness_px, theme.accent);

            if (knobs.show_sample_points and
                (i % knobs.sample_marker_every == 0 or i == knobs.sample_count - 1))
            {
                draw.fillRect(frame, draw.rect(x - 1.5, y - 1.5, 3.0, 3.0), theme.accent);
            }

            prev_x = x;
            prev_y = y;
        }
    }
};

fn plotAmplitudePx(plot: draw.Rect, baseline_y: f32) f32 {
    const max_down = @max(baseline_y - plot.y - 1.0, 0.0);
    const max_up = @max(plot.top() - baseline_y - 1.0, 0.0);
    return @min(knobs.amplitude_px, @min(max_down, max_up));
}

fn sampleWaveY(x_01: f32, baseline_y: f32, phase: f32, amplitude_px: f32) f32 {
    const wave_phase = x_01 * knobs.cycles_across_plot * tau + phase;
    return baseline_y + @sin(wave_phase) * amplitude_px;
}

const runtime = work.Runtime(App);

export fn yoke_get_api() callconv(.c) *const work.Api {
    return runtime.api();
}

