const std = @import("std");

pub const abi_version: u32 = 0;
pub const module_state_alignment: comptime_int = 16;

pub const symbols = struct {
    pub const get_api = "yoke_get_api";
};

pub const Button = extern struct {
    is_down: u8 = 0,
    changed: u8 = 0,
};

pub fn buttonPressed(button: Button) bool {
    return button.is_down != 0 and button.changed != 0;
}

pub fn buttonReleased(button: Button) bool {
    return button.is_down == 0 and button.changed != 0;
}

pub const Input = extern struct {
    quit_requested: u8 = 0,
    client_width: u32 = 0,
    client_height: u32 = 0,

    mouse_x: f32 = 0,
    mouse_y: f32 = 0,

    escape: Button = .{},
    space: Button = .{},
    mouse_left: Button = .{},
};

pub const TickContext = extern struct {
    dt_ns: u64,
    tick_index: u64,
    input: Input,
};

pub const RenderCommandKind = enum(u32) {
    clear = 1,
    fill_rect = 2,
    stroke_rect = 3,
};

pub const RenderCommand = extern struct {
    kind: u32 = 0,
    color: u32 = 0,
    thickness: f32 = 1.0,

    x0: f32 = 0,
    y0: f32 = 0,
    x1: f32 = 0,
    y1: f32 = 0,
};

pub const CommandBuffer = extern struct {
    commands: [*]RenderCommand,
    count: u32,
    capacity: u32,
};

pub const RenderTarget = extern struct {
    width: u32,
    height: u32,
};

pub const CursorKind = enum(u32) {
    arrow = 0,
    hand = 1,
    size_all = 2,
};

pub const Frame = extern struct {
    target: RenderTarget,
    command_buffer: CommandBuffer,
    cursor_kind: u32,
};

pub const PlatformMemory = extern struct {
    permanent_storage_size: u64,
    permanent_storage: *anyopaque,
    transient_storage_size: u64,
    transient_storage: *anyopaque,
};

pub const InitFn = *const fn (memory: *PlatformMemory) callconv(.c) void;
pub const ReloadFn = *const fn (memory: *PlatformMemory) callconv(.c) void;
pub const TickFn = *const fn (memory: *PlatformMemory, ctx: TickContext) callconv(.c) void;
pub const RenderFn = *const fn (memory: *PlatformMemory, ctx: TickContext, frame: *Frame) callconv(.c) void;

pub const Api = extern struct {
    abi_version: u32,
    required_permanent_storage_size: u64,
    required_transient_storage_size: u64,
    init: InitFn,
    on_reload: ReloadFn,
    update: TickFn,
    render: RenderFn,
};

pub const GetApiFn = *const fn () callconv(.c) *const Api;

pub fn RGB(r: u8, g: u8, b: u8) u32 {
    return (@as(u32, r) << 16) | (@as(u32, g) << 8) | @as(u32, b);
}

pub fn setCursor(frame: *Frame, kind: CursorKind) void {
    frame.cursor_kind = @intFromEnum(kind);
}

pub fn pushCommand(frame: *Frame, cmd: RenderCommand) bool {
    if (frame.command_buffer.count >= frame.command_buffer.capacity) return false;
    frame.command_buffer.commands[frame.command_buffer.count] = cmd;
    frame.command_buffer.count += 1;
    return true;
}

pub fn clear(frame: *Frame, color: u32) void {
    _ = pushCommand(frame, .{
        .kind = @intFromEnum(RenderCommandKind.clear),
        .color = color,
    });
}

pub fn fillRect(
    frame: *Frame,
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
    color: u32,
) void {
    _ = pushCommand(frame, .{
        .kind = @intFromEnum(RenderCommandKind.fill_rect),
        .color = color,
        .x0 = x0,
        .y0 = y0,
        .x1 = x1,
        .y1 = y1,
    });
}

pub fn strokeRect(
    frame: *Frame,
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
    thickness: f32,
    color: u32,
) void {
    _ = pushCommand(frame, .{
        .kind = @intFromEnum(RenderCommandKind.stroke_rect),
        .color = color,
        .thickness = thickness,
        .x0 = x0,
        .y0 = y0,
        .x1 = x1,
        .y1 = y1,
    });
}

