const abi = @import("abi.zig");
const theme = @import("themes.zig").default;
const draw = @import("draw.zig");

const tracy = @import("tracy.zig");

const WorkState = struct {
    reload_count: u32 = 0,
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
    var zone = tracy.zoneN("work_update");
    defer zone.end();

    _ = memory;
    _ = ctx;
}

fn render(memory: *abi.PlatformMemory, ctx: abi.TickContext, frame: *abi.Frame) callconv(.c) void {
    var zone = tracy.zoneN("work_render");
    defer zone.end();

    _ = memory;

    draw.begin(frame, theme);
    defer draw.cursorSquare(frame, ctx.input.mouse_x, ctx.input.mouse_y, theme.cursor);
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
