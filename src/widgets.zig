const std = @import("std");
const abi = @import("abi.zig");
const themes = @import("themes.zig");
const draw = @import("draw.zig");

pub const DraggablePanel = struct {
    rect: draw.Rect,
    dragging: bool = false,
    drag_start_mouse_x: f32 = 0,
    drag_start_mouse_y: f32 = 0,
    drag_start_rect_x: f32 = 0,
    drag_start_rect_y: f32 = 0,

    pub fn init(x: f32, y: f32, w: f32, h: f32) DraggablePanel {
        return .{ .rect = .{ .x = x, .y = y, .w = w, .h = h } };
    }

    pub fn resetPosition(self: *DraggablePanel, x: f32, y: f32) void {
        self.rect.x = x;
        self.rect.y = y;
        self.dragging = false;
    }

    pub fn hovered(self: *const DraggablePanel, input: abi.Input) bool {
        return draw.contains(self.rect, input.mouse_x, input.mouse_y);
    }

    pub fn update(self: *DraggablePanel, input: abi.Input) void {
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
    }

    pub fn draw_panel(
        self: *const DraggablePanel,
        frame: *abi.Frame,
        theme: themes.Theme,
        ctx: abi.TickContext,
        header_height: f32,
    ) void {
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

        draw.fillRect(frame, .{
            .x = self.rect.x,
            .y = self.rect.top() - header_height,
            .w = self.rect.w,
            .h = header_height,
        }, if (self.dragging) theme.accent_active else if (hovering) theme.accent_hover else theme.accent);

        if (self.dragging) {
            abi.setCursor(frame, .size_all);
            draw.orbitSquares(
                frame,
                ctx.input.mouse_x,
                ctx.input.mouse_y,
                ctx.tick_index,
                12.0,
                4.0,
                theme.accent_active,
            );
        } else if (hovering) {
            abi.setCursor(frame, .hand);
        }
    }
};

