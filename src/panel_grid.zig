const std = @import("std");

const abi = @import("abi.zig");
const draw = @import("draw.zig");
const layz = @import("layz.zig");
const themes = @import("themes.zig");
const widgets = @import("widgets.zig");

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

    pub fn draw_grid(self: *const PanelGrid, frame: *abi.Frame, theme: themes.Theme, ctx: abi.TickContext) void {
        const header_height: f32 = 28.0;

        for (self.panels) |panel| {
            panel.draw_panel(frame, theme, ctx, header_height);
        }
    }
};

pub fn render(
    grid: *PanelGrid,
    frame: *abi.Frame,
    theme: themes.Theme,
    ctx: abi.TickContext,
) !void {
    try grid.updateLayout(ctx.input.client_width, ctx.input.client_height);
    grid.draw_grid(frame, theme, ctx);
}

