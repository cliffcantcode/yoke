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

fn drawGradient(buffer: *const abi.SoftwareBuffer, blue_offset: u32, green_offset: u32) void {
    var y: u32 = 0;
    while (y < buffer.height) : (y += 1) {
        const row_base = buffer.memory + @as(usize, y) * @as(usize, buffer.pitch);
        const row: [*]u32 = @ptrCast(@alignCast(row_base));

        var x: u32 = 0;
        while (x < buffer.width) : (x += 1) {
            const blue = (x * 2 + blue_offset) & 0xff;
            const green = (y + green_offset) & 0xff;

            // 0x00RRGGBB
            row[x] = (green << 8) | blue;
        }
    }
}

fn render(state: *abi.State, ctx: abi.TickContext, buffer: *const abi.SoftwareBuffer) callconv(.c) void {
    state.render_count += 1;

    const blue_offset: u32 = @truncate(state.update_count);
    const green_offset: u32 = @truncate(state.render_count);

    drawGradient(buffer, blue_offset, green_offset);

    if (state.render_count % 60 == 0) {
        std.debug.print(
            "reloads={d} size={d}x{d} counter={d} updates={d} renders={d}\n",
            .{
                state.reload_count,
                ctx.input.client_width,
                ctx.input.client_height,
                state.counter,
                state.update_count,
                state.render_count,
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

