const std = @import("std");

pub const abi_version: u32 = 1;

pub const symbols = struct {
    pub const get_api = "yoke_get_api";
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

