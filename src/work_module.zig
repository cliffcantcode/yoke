const std = @import("std");

const abi = @import("abi.zig");
const theme = @import("themes.zig").default;
const draw = @import("draw.zig");
const text = @import("text.zig");
const widgets = @import("widgets.zig");

const WorkState = struct {
    reload_count: u32 = 0,
    update_count: u64 = 0,
    render_count: u64 = 0,
    panel: widgets.DraggablePanel = widgets.DraggablePanel.init(140, 120, 240, 140),
};

comptime {
    if (@alignOf(WorkState) > abi.module_state_alignment) {
        @compileError("WorkState alignment exceeds abi.module_state_alignment");
    }
}

fn getState(memory: *abi.PlatformMemory) *WorkState {
    return @ptrCast(@alignCast(memory.permanent_storage));
}

fn init(memory: *abi.PlatformMemory) callconv(.c) void {
    const state = getState(memory);
    state.* = .{};
}

fn onReload(memory: *abi.PlatformMemory) callconv(.c) void {
    const state = getState(memory);
    state.reload_count += 1;
}

fn update(memory: *abi.PlatformMemory, ctx: abi.TickContext) callconv(.c) void {
    const state = getState(memory);
    state.update_count += 1;

    if (abi.buttonPressed(ctx.input.escape)) {
        state.panel.resetPosition(140, 120);
    }

    state.panel.update(ctx.input);
}

fn render(memory: *abi.PlatformMemory, ctx: abi.TickContext, frame: *abi.Frame) callconv(.c) void {
    const state = getState(memory);
    state.render_count += 1;

    draw.begin(frame, theme);
    draw.originMarker(frame, theme);

    defer draw.cursorSquare(frame, ctx.input.mouse_x, ctx.input.mouse_y, theme.cursor);

    draw.line(
        frame,
        0,
        0,
        @as(f32, @floatFromInt(ctx.input.client_width - 1)),
        @as(f32, @floatFromInt(ctx.input.client_height - 1)),
        3,
        theme.panel_border,
    );

    draw.line(
        frame,
        0,
        @as(f32, @floatFromInt(ctx.input.client_height - 1)),
        @as(f32, @floatFromInt(ctx.input.client_width - 1)),
        0,
        3,
        theme.accent,
    );

    state.panel.draw_panel(frame, theme, ctx, 10.0);

    text.drawTopLeft(
        frame,
        state.panel.rect.x + 8,
        state.panel.rect.top() - 3,
        "YOKE PANEL",
        .{ .scale = 2 },
        theme.text,
    );

    var line_buf: [64]u8 = undefined;
    const line = std.fmt.bufPrint(&line_buf, "RELOADS {d}", .{state.reload_count}) catch "RELOADS ?";
    text.drawTopLeft(
        frame,
        state.panel.rect.x + 8,
        state.panel.rect.top() - 24,
        line,
        .{ .scale = 2 },
        theme.text_muted,
    );

    const line2 = std.fmt.bufPrint(&line_buf, "UPDATES {d}", .{state.update_count}) catch "UPDATES ?";
    text.drawTopLeft(
        frame,
        state.panel.rect.x + 8,
        state.panel.rect.top() - 42,
        line2,
        .{ .scale = 2 },
        theme.text_muted,
    );

    text.drawTopLeft(
        frame,
        state.panel.rect.x + 8,
        state.panel.rect.y + 28,
        "DRAG WITH LMB",
        .{ .scale = 2 },
        theme.accent,
    );

    text.drawTopLeft(
        frame,
        state.panel.rect.x + 8,
        state.panel.rect.y + 12,
        "ESC RESETS",
        .{ .scale = 2 },
        theme.text_muted,
    );

    if (state.render_count % 60 == 0) {
        std.debug.print(
            "reloads={d} mouse=({d:.1}, {d:.1}) panel=({d:.1}, {d:.1}) dragging={any}\n",
            .{
                state.reload_count,
                ctx.input.mouse_x,
                ctx.input.mouse_y,
                state.panel.rect.x,
                state.panel.rect.y,
                state.panel.dragging,
            },
        );
    }
}

const api = abi.Api{
    .abi_version = abi.abi_version,
    .required_permanent_storage_size = @sizeOf(WorkState),
    .required_transient_storage_size = 0,
    .init = &init,
    .on_reload = &onReload,
    .update = &update,
    .render = &render,
};

export fn yoke_get_api() callconv(.c) *const abi.Api {
    return &api;
}

