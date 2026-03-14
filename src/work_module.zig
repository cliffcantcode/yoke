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
    state.counter += 1;
    state.update_count += 1;
    state.sim_time_ns += ctx.dt_ns;
}

fn render(state: *abi.State, ctx: abi.TickContext) callconv(.c) void {
    state.render_count += 1;

    if (state.render_count % 15 == 0) {
        std.debug.print(
            "reloads={d} updates={d} renders={d} counter={d} sim={d:.3}s render_dt={d:.3}ms render_tick={d}\n",
            .{
                state.reload_count,
                state.update_count,
                state.render_count,
                state.counter,
                abi.nsToSeconds(state.sim_time_ns),
                abi.nsToSeconds(ctx.dt_ns) * 1000.0,
                ctx.tick_index,
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

