const std = @import("std");

const abi = @import("abi.zig");
const themes = @import("themes.zig");
const draw = @import("draw.zig");
const assert = @import("assert.zig");
const reflection = @import("reflection.zig");

pub const DraggablePanel = struct {
    rect: draw.Rect,
    drag_start_mouse_x: f32 = 0,
    drag_start_mouse_y: f32 = 0,
    drag_start_rect_x: f32 = 0,
    drag_start_rect_y: f32 = 0,
    dragging: bool = false,
    _padding: [3]u8 = undefined,

    comptime {
        reflection.assertNoWastedBytePadding(@This());
    }

    pub fn init(x: f32, y: f32, w: f32, h: f32) DraggablePanel {
        const panel = DraggablePanel{ .rect = .{ .x = x, .y = y, .w = w, .h = h } };
        panel.asserts();

        return panel;
    }

    pub fn resetPosition(self: *DraggablePanel, x: f32, y: f32) void {
        self.asserts();
        assert.is_finite(x, "DraggablePanel.resetPosition.x", .{});
        assert.is_finite(y, "DraggablePanel.resetPosition.y", .{});

        self.rect.x = x;
        self.rect.y = y;
        self.dragging = false;
    }

    pub fn hovered(self: *const DraggablePanel, input: abi.Input) bool {
        return draw.contains(self.rect, input.mouse_x, input.mouse_y);
    }

    pub fn update(self: *DraggablePanel, input: abi.Input) void {
        self.asserts();

        if (abi.buttonPressed(input.mouse_left) and self.hovered(input)) {
            self.dragging = true;
            self.drag_start_mouse_x = input.mouse_x;
            self.drag_start_mouse_y = input.mouse_y;
            self.drag_start_rect_x = self.rect.x;
            self.drag_start_rect_y = self.rect.y;
        }

        if (abi.buttonReleased(input.mouse_left)) {
            self.dragging = false;
        }

        if (self.dragging and input.mouse_left.is_down != 0) {
            const delta_x = input.mouse_x - self.drag_start_mouse_x;
            const delta_y = input.mouse_y - self.drag_start_mouse_y;

            var next_x = self.drag_start_rect_x + delta_x;
            var next_y = self.drag_start_rect_y + delta_y;

            const max_x = @max(@as(f32, @floatFromInt(input.client_width)) - self.rect.w, 0.0);
            const max_y = @max(@as(f32, @floatFromInt(input.client_height)) - self.rect.h, 0.0);

            next_x = std.math.clamp(next_x, 0.0, max_x);
            next_y = std.math.clamp(next_y, 0.0, max_y);

            self.rect.x = next_x;
            self.rect.y = next_y;
        }

        self.asserts();
    }

    pub fn headerRect(self: *const DraggablePanel, header_height: f32) draw.Rect {
        self.asserts();
        assert.is_finite(header_height, "DraggablePanel.header_height", .{});
        assert.hard(header_height >= 0, "header_height must be >= 0, got {d}", .{header_height});
        assert.hard(header_height <= self.rect.h, "header_height {d} exceeds panel height {d}", .{ header_height, self.rect.h });

        return draw.rect(
            self.rect.x + draw.panel_border_thickness,
            self.rect.top() - header_height,
            @max(self.rect.w - 2.0 * draw.panel_border_thickness, 0.0),
            @max(header_height - draw.panel_border_thickness, 0.0),
        );
    }

    pub fn draw_panel(
        self: *const DraggablePanel,
        frame: *abi.Frame,
        theme: themes.Theme,
        ctx: abi.TickContext,
        header_height: f32,
    ) void {
        self.asserts();
        assert.is_finite(header_height, "DraggablePanel.header_height", .{});
        assert.hard(header_height >= 0, "header_height must be >= 0, got {d}", .{header_height});
        assert.hard(header_height <= self.rect.h, "header_height {d} exceeds panel height {d}", .{ header_height, self.rect.h });

        const hovering = self.hovered(ctx.input);

        const fill = if (self.dragging)
            theme.panel_bg_active
        else if (hovering)
            theme.panel_bg_hover
        else
            theme.panel_bg;

        const border = if (self.dragging)
            theme.accent_active
        else if (hovering)
            theme.accent_hover
        else
            theme.panel_border;

        draw.panel(frame, self.rect, fill, border);

        const header_color = if (self.dragging)
            theme.accent_active
        else if (hovering)
            theme.accent_hover
        else
            theme.accent;

        const header_rect = self.headerRect(header_height);
        if (header_rect.w > 0 and header_rect.h > 0) {
            draw.fillRoundedRect(
                frame,
                header_rect,
                header_color,
                @max(draw.panel_corner_radius - draw.panel_border_thickness, 0.0),
                draw.RoundedCorners.top,
            );
        }
    }

    fn asserts(self: *const DraggablePanel) void {
        assert.is_finite(self.rect.x, "DraggablePanel.rect.x", .{});
        assert.is_finite(self.rect.y, "DraggablePanel.rect.y", .{});
        assert.is_finite(self.rect.w, "DraggablePanel.rect.w", .{});
        assert.is_finite(self.rect.h, "DraggablePanel.rect.h", .{});
        assert.hard(self.rect.w >= 0, "DraggablePanel width must be >= 0, got {d}", .{self.rect.w});
        assert.hard(self.rect.h >= 0, "DraggablePanel height must be >= 0, got {d}", .{self.rect.h});
    }
};

