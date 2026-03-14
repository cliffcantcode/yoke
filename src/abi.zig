const std = @import("std");

pub const abi_version: u32 = 0;

pub const symbols = struct {
    pub const get_api = "yoke_get_api";
};

pub const Button = extern struct {
    is_down: u8 = 0,
    changed: u8 = 0,
};

pub const Input = extern struct {
    quit_requested: u8 = 0,
    client_width: u32 = 0,
    client_height: u32 = 0,

    escape: Button = .{},
    space: Button = .{},
};

pub const State = extern struct {
    initialized: u8 = 0,
    reload_count: u32 = 0,

    counter: i64 = 0,
    update_count: u64 = 0,
    render_count: u64 = 0,
    sim_time_ns: u64 = 0,
};

pub const TickContext = extern struct {
    dt_ns: u64,
    tick_index: u64,
    input: Input,
};

pub const InitFn = *const fn (state: *State) callconv(.c) void;
pub const ReloadFn = *const fn (state: *State) callconv(.c) void;
pub const TickFn = *const fn (state: *State, ctx: TickContext) callconv(.c) void;

pub const Api = extern struct {
    abi_version: u32,
    init: InitFn,
    on_reload: ReloadFn,
    update: TickFn,
    render: TickFn,
};

pub const GetApiFn = *const fn () callconv(.c) *const Api;

pub fn nsToSeconds(ns: u64) f64 {
    return @as(f64, @floatFromInt(ns)) / @as(f64, @floatFromInt(std.time.ns_per_s));
}

pub fn buttonPressed(button: Button) bool {
    return button.is_down != 0 and button.changed != 0;
}

pub fn buttonReleased(button: Button) bool {
    return button.is_down == 0 and button.changed != 0;
}

