const std = @import("std");

const abi = @import("abi.zig");
const theme = @import("themes.zig").default;
const draw = @import("draw.zig");
const widgets = @import("widgets.zig");

const WorkState = struct {
    reload_count: u32 = 0,
    update_count: u64 = 0,
    render_count: u64 = 0,

    rect_x: f32 = 140,
    rect_y: f32 = 120,
    rect_w: f32 = 240,
    rect_h: f32 = 140,

    dragging: u8 = 0,
    drag_start_mouse_x: f32 = 0,
    drag_start_mouse_y: f32 = 0,
    drag_start_rect_x: f32 = 0,
    drag_start_rect_y: f32 = 0,
};

comptime {
    if (@alignOf(WorkState) > abi.module_state_alignment) {
        @compileError("WorkState alignment exceeds abi.module_state_alignment");
    }
}

fn getState(module_state: *anyopaque) *WorkState {
    return @ptrCast(@alignCast(module_state));
}

fn currentRect(state: *const WorkState) draw.Rect {
    return .{
        .x = state.rect_x,
        .y = state.rect_y,
        .w = state.rect_w,
        .h = state.rect_h,
    };
}

fn init(module_state: *anyopaque) callconv(.c) void {
    const state = getState(module_state);
    state.* = .{};
}

fn onReload(module_state: *anyopaque) callconv(.c) void {
    const state = getState(module_state);
    state.reload_count += 1;
}

fn update(module_state: *anyopaque, ctx: abi.TickContext) callconv(.c) void {
    const state = getState(module_state);
    state.update_count += 1;

    if (abi.buttonPressed(ctx.input.escape)) {
        state.rect_x = 140;
        state.rect_y = 120;
        state.dragging = 0;
    }

    const r = currentRect(state);

    if (abi.buttonPressed(ctx.input.mouse_left) and draw.contains(
        r,
        ctx.input.mouse_x,
        ctx.input.mouse_y,
    )) {
        state.dragging = 1;
        state.drag_start_mouse_x = ctx.input.mouse_x;
        state.drag_start_mouse_y = ctx.input.mouse_y;
        state.drag_start_rect_x = state.rect_x;
        state.drag_start_rect_y = state.rect_y;
    }

    if (abi.buttonReleased(ctx.input.mouse_left)) {
        state.dragging = 0;
    }

    if (state.dragging != 0 and ctx.input.mouse_left.is_down != 0) {
        const delta_x = ctx.input.mouse_x - state.drag_start_mouse_x;
        const delta_y = ctx.input.mouse_y - state.drag_start_mouse_y;

        var next_x = state.drag_start_rect_x + delta_x;
        var next_y = state.drag_start_rect_y + delta_y;

        const max_x = @max(@as(f32, @floatFromInt(ctx.input.client_width)) - state.rect_w, 0.0);
        const max_y = @max(@as(f32, @floatFromInt(ctx.input.client_height)) - state.rect_h, 0.0);

        next_x = std.math.clamp(next_x, 0.0, max_x);
        next_y = std.math.clamp(next_y, 0.0, max_y);

        state.rect_x = next_x;
        state.rect_y = next_y;
    }
}

fn render(module_state: *anyopaque, ctx: abi.TickContext, frame: *abi.Frame) callconv(.c) void {
    const state = getState(module_state);
    state.render_count += 1;

    const r = currentRect(state);
    const hovering = draw.contains(r, ctx.input.mouse_x, ctx.input.mouse_y);

    draw.begin(frame, theme);
    draw.originMarker(frame, theme);

    widgets.panelWithHeader(
        frame,
        r,
        theme,
        hovering,
        state.dragging != 0,
        10,
    );

    draw.cursor(frame, ctx.input.mouse_x, ctx.input.mouse_y, theme.cursor);

    if (state.render_count % 60 == 0) {
        std.debug.print(
            "reloads={d} mouse=({d:.1}, {d:.1}) rect=({d:.1}, {d:.1}) dragging={d}\n",
            .{
                state.reload_count,
                ctx.input.mouse_x,
                ctx.input.mouse_y,
                state.rect_x,
                state.rect_y,
                state.dragging,
            },
        );
    }
}

const api = abi.Api{
    .abi_version = abi.abi_version,
    .module_state_size = @sizeOf(WorkState),
    .init = &init,
    .on_reload = &onReload,
    .update = &update,
    .render = &render,
};

export fn yoke_get_api() callconv(.c) *const abi.Api {
    return &api;
}

