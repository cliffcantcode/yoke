const std = @import("std");

const abi = @import("abi.zig");
const theme = @import("themes.zig").default;
const draw = @import("draw.zig");
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
    return @ptrCast(@alignCast(memory));
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

    state.panel.draw_panel(frame, theme, ctx, 10.0);

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

