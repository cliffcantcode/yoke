const std = @import("std");

const abi = @import("abi.zig");
const draw = @import("draw.zig");
const layz = @import("layz.zig");
const themes = @import("themes.zig");
const widgets = @import("widgets.zig");
const layout = @import("layout.zig");
const text = @import("text.zig");

pub const DashboardInfo = struct {
    module_name: []const u8,
    reload_count: u32,
    update_count: u64,
    render_count: u64,
    input: abi.Input,
};

pub const PanelGrid = struct {
    layout: layz.Context,
    panels: [4]widgets.DraggablePanel = .{
        widgets.DraggablePanel.init(0, 0, 100, 100),
        widgets.DraggablePanel.init(0, 0, 100, 100),
        widgets.DraggablePanel.init(0, 0, 100, 100),
        widgets.DraggablePanel.init(0, 0, 100, 100),
    },

    pub fn init(allocator: std.mem.Allocator) PanelGrid {
        return .{
            .layout = layz.Context.init(allocator),
        };
    }

    pub fn deinit(self: *PanelGrid) void {
        self.layout.deinit();
    }

    pub fn updateLayout(self: *PanelGrid, client_width: u32, client_height: u32) !void {
        const root_size = layz.Size{
            .width = @floatFromInt(client_width),
            .height = @floatFromInt(client_height),
        };

        try self.layout.begin(root_size);

        try self.layout.open(.{
            .id = layz.id("panel_grid"),
            .layout = .{
                .sizing = .{
                    .width = .{ .grow = .{} },
                    .height = .{ .grow = .{} },
                },
                .padding = layz.Padding.all(24),
                .child_gap = 16,
                .direction = .top_to_bottom,
            },
        });

        inline for ([_][]const u8{ "row_0", "row_1" }, 0..) |row_label, row_index| {
            try self.layout.open(.{
                .id = layz.id(row_label),
                .layout = .{
                    .sizing = .{
                        .width = .{ .grow = .{} },
                        .height = .{ .grow = .{} },
                    },
                    .child_gap = 16,
                    .direction = .left_to_right,
                },
            });

            inline for ([_][]const u8{
                if (row_index == 0) "panel_0" else "panel_2",
                if (row_index == 0) "panel_1" else "panel_3",
            }) |panel_label| {
                try self.layout.open(.{
                    .id = layz.id(panel_label),
                    .layout = .{
                        .sizing = .{
                            .width = .{ .grow = .{} },
                            .height = .{ .grow = .{} },
                        },
                    },
                });
                self.layout.close();
            }

            self.layout.close();
        }

        self.layout.close();
        try self.layout.end();

        const ids = [_]layz.Id{
            layz.id("panel_0"),
            layz.id("panel_1"),
            layz.id("panel_2"),
            layz.id("panel_3"),
        };

        inline for (ids, 0..) |panel_id, panel_index| {
            const rect = self.layout.rectOf(panel_id) orelse unreachable;
            self.panels[panel_index].dragging = false;
            self.panels[panel_index].rect = draw.rect(rect.x, rect.y, rect.width, rect.height);
        }
    }

    pub fn draw_grid(
        self: *const PanelGrid,
        frame: *abi.Frame,
        theme: themes.Theme,
        ctx: abi.TickContext,
        info: DashboardInfo,
    ) void {
        const header_height: f32 = 28.0;

        for (self.panels, 0..) |panel, panel_index| {
            panel.draw_panel(frame, theme, ctx, header_height);
            drawPanelBody(panel_index, panel, frame, theme, info, header_height);
        }
    }
};

fn drawPanelBody(
    panel_index: usize,
    panel: widgets.DraggablePanel,
    frame: *abi.Frame,
    theme: themes.Theme,
    info: DashboardInfo,
    header_height: f32,
) void {
    const title_opts = text.Options{ .scale = 2.0 };
    const body_opts = text.Options{ .scale = 2.0 };
    const small_opts = text.Options{ .scale = 1.0 };

    var value_buf: [128]u8 = undefined;
    var ui = layout.Cursor.fromPanel(panel.rect, header_height, 10.0, 6.0);

    switch (panel_index) {
        0 => {
            layout.title(frame, &ui, "YOKE STATUS", theme, title_opts);
            layout.separator(frame, &ui, theme);

            const reloads = std.fmt.bufPrint(&value_buf, "{d}", .{info.reload_count}) catch "?";
            layout.labelValue(frame, &ui, "Reloads", reloads, theme, body_opts, body_opts);

            const updates = std.fmt.bufPrint(&value_buf, "{d}", .{info.update_count}) catch "?";
            layout.labelValue(frame, &ui, "Updates", updates, theme, body_opts, body_opts);

            const renders = std.fmt.bufPrint(&value_buf, "{d}", .{info.render_count}) catch "?";
            layout.labelValue(frame, &ui, "Renders", renders, theme, body_opts, body_opts);

            layout.separator(frame, &ui, theme);
            layout.note(frame, &ui, info.module_name, theme.accent, small_opts);
            layout.note(frame, &ui, "Managed by Yoke.", theme.text_muted, small_opts);

            const progress = @as(f32, @floatFromInt(@mod(info.update_count, 120))) / 119.0;
            layout.progressBar(frame, &ui, theme, progress, 10.0);
        },
        1 => {
            layout.title(frame, &ui, "INPUT", theme, title_opts);
            layout.separator(frame, &ui, theme);

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
                if (info.input.escape.is_down != 0) "ESC is down" else "ESC is up",
                theme.text_muted,
                small_opts,
            );
            layout.note(
                frame,
                &ui,
                if (info.input.space.is_down != 0) "SPACE is down" else "SPACE is up",
                theme.text_muted,
                small_opts,
            );

            const mouse_progress = if (info.input.client_width == 0)
                0.0
            else
                @min(@max(info.input.mouse_x / @as(f32, @floatFromInt(info.input.client_width)), 0.0), 1.0);
            layout.progressBar(frame, &ui, theme, mouse_progress, 10.0);
        },
        2 => {
            layout.title(frame, &ui, "MODULE", theme, title_opts);
            layout.separator(frame, &ui, theme);

            layout.note(frame, &ui, info.module_name, theme.text, body_opts);

            layout.labelValue(frame, &ui, "Layout", "2 x 2 GRID", theme, body_opts, body_opts);
            layout.labelValue(frame, &ui, "Owner", "YOKE", theme, body_opts, body_opts);
            layout.labelValue(frame, &ui, "Focus", "USER WORK", theme, body_opts, body_opts);

            layout.separator(frame, &ui, theme);
            layout.note(frame, &ui, "Panels replace the old user-side panel.", theme.text_muted, small_opts);

            const progress = @as(f32, @floatFromInt(@mod(info.render_count, 120))) / 119.0;
            layout.progressBar(frame, &ui, theme, progress, 10.0);
        },
        3 => {
            layout.title(frame, &ui, "LOOP", theme, title_opts);
            layout.separator(frame, &ui, theme);

            layout.labelValue(frame, &ui, "Update Hz", "60", theme, body_opts, body_opts);
            layout.labelValue(frame, &ui, "Render Hz", "60", theme, body_opts, body_opts);

            const frame_count = std.fmt.bufPrint(&value_buf, "{d}", .{info.render_count}) catch "?";
            layout.labelValue(frame, &ui, "Frame", frame_count, theme, body_opts, body_opts);

            layout.separator(frame, &ui, theme);
            layout.note(frame, &ui, "Tight host-side feedback loop.", theme.accent, small_opts);
            layout.note(frame, &ui, "Old draggable panel removed.", theme.text_muted, small_opts);

            const progress = @as(f32, @floatFromInt(@mod(info.reload_count, 60))) / 59.0;
            layout.progressBar(frame, &ui, theme, progress, 10.0);
        },
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
    try grid.updateLayout(ctx.input.client_width, ctx.input.client_height);
    grid.draw_grid(frame, theme, ctx, info);
}

