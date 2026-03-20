const std = @import("std");

const abi = @import("abi.zig");
const theme = @import("themes.zig").default;
const draw = @import("draw.zig");
const text = @import("text.zig");
const widgets = @import("widgets.zig");
const layout = @import("layout.zig");

const tracy = @import("tracy.zig");

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
    var zone = tracy.zoneN("update");
    defer zone.end();

    const state = getState(memory);
    state.update_count += 1;

    if (abi.buttonPressed(ctx.input.escape)) {
        state.panel.resetPosition(140, 120);
    }

    state.panel.update(ctx.input);
}

fn render(memory: *abi.PlatformMemory, ctx: abi.TickContext, frame: *abi.Frame) callconv(.c) void {
    var zone = tracy.zoneN("render");
    defer zone.end();

    const state = getState(memory);
    state.render_count += 1;

    defer draw.cursorSquare(frame, ctx.input.mouse_x, ctx.input.mouse_y, theme.cursor);

    draw.begin(frame, theme);

    state.panel.draw_panel(frame, theme, ctx, 10.0);

    const title_opts = text.Options{ .scale = 2.0 };
    const body_opts = text.Options{ .scale = 2.0 };
    const small_opts = text.Options{ .scale = 1.0 };

    var value_buf: [64]u8 = undefined;
    var ui = layout.Cursor.fromPanel(state.panel.rect, 10.0, 10.0, 6.0);

    layout.title(frame, &ui, "YOKE PANEL", theme, title_opts);
    layout.separator(frame, &ui, theme);

    const reloads = std.fmt.bufPrint(&value_buf, "{d}", .{state.reload_count}) catch "?";
    layout.labelValue(frame, &ui, "Reloads", reloads, theme, body_opts, body_opts);

    const updates = std.fmt.bufPrint(&value_buf, "{d}", .{state.update_count}) catch "?";
    layout.labelValue(frame, &ui, "Updates", updates, theme, body_opts, body_opts);

    const dragging = if (state.panel.dragging) "YES" else "NO";
    layout.labelValue(frame, &ui, "Dragging", dragging, theme, body_opts, body_opts);

    layout.separator(frame, &ui, theme);
    layout.note(frame, &ui, "Drag with the mouse.", theme.accent, small_opts);
    layout.note(frame, &ui, "ESC resets", theme.text_muted, small_opts);

    const progress = @as(f32, @floatFromInt(@mod(state.update_count, 120))) / 119.0;
    layout.progressBar(frame, &ui, theme, progress, 10.0);

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

