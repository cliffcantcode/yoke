const std = @import("std");
const abi = @import("abi.zig");

fn init(state: *abi.State) callconv(.c) void {
    if (state.initialized == 0) {
        state.* = .{};
        state.initialized = 1;
    }
}

fn onReload(state: *abi.State) callconv(.c) void {
    state.reload_count += 1;
}

fn update(state: *abi.State, ctx: abi.TickContext) callconv(.c) void {
    state.update_count += 1;
    state.sim_time_ns += ctx.dt_ns;

    state.counter += 1;

    if (abi.buttonPressed(ctx.input.space)) {
        state.counter += 60;
    }

    if (abi.buttonPressed(ctx.input.escape)) {
        state.counter = 0;
    }
}

fn render(state: *abi.State, ctx: abi.TickContext) callconv(.c) void {
    state.render_count += 1;

    if (state.render_count % 30 == 0) {
        std.debug.print(
            "reloads={d} size={d}x{d} counter={d} updates={d} renders={d} space(down={d} changed={d}) escape(down={d} changed={d})\n",
            .{
                state.reload_count,
                ctx.input.client_width,
                ctx.input.client_height,
                state.counter,
                state.update_count,
                state.render_count,
                ctx.input.space.is_down,
                ctx.input.space.changed,
                ctx.input.escape.is_down,
                ctx.input.escape.changed,
            },
        );
    }
}

const api = abi.Api{
    .abi_version = abi.abi_version,
    .init = &init,
    .on_reload = &onReload,
    .update = &update,
    .render = &render,
};

export fn yoke_get_api() callconv(.c) *const abi.Api {
    return &api;
}

