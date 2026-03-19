const std = @import("std");
const build_options = @import("build_options");

pub const enabled = build_options.tracy_enable;

pub const SourceLocation = extern struct {
    name: ?[*:0]const u8,
    function: [*:0]const u8,
    file: [*:0]const u8,
    line: u32,
    color: u32,
};

pub const ZoneContext = extern struct {
    id: u32,
    active: i32,
};

extern fn yoke_tracy_zone_begin(srcloc: *const SourceLocation, depth: i32, active: i32) callconv(.c) ZoneContext;
extern fn yoke_tracy_zone_end(ctx: ZoneContext) callconv(.c) void;
extern fn yoke_tracy_zone_text(ctx: ZoneContext, txt: [*]const u8, size: usize) callconv(.c) void;
extern fn yoke_tracy_zone_name(ctx: ZoneContext, txt: [*]const u8, size: usize) callconv(.c) void;
extern fn yoke_tracy_zone_color(ctx: ZoneContext, color: u32) callconv(.c) void;
extern fn yoke_tracy_zone_value(ctx: ZoneContext, value: u64) callconv(.c) void;
extern fn yoke_tracy_frame_mark(name: ?[*:0]const u8) callconv(.c) void;
extern fn yoke_tracy_set_thread_name(name: [*:0]const u8) callconv(.c) void;
extern fn yoke_tracy_message(txt: [*]const u8, size: usize, color: u32) callconv(.c) void;
extern fn yoke_tracy_alloc(ptr: ?*const anyopaque, size: usize) callconv(.c) void;
extern fn yoke_tracy_free(ptr: ?*const anyopaque) callconv(.c) void;
extern fn yoke_tracy_startup() callconv(.c) void;
extern fn yoke_tracy_shutdown() callconv(.c) void;

pub const Zone = struct {
    ctx: ZoneContext = .{ .id = 0, .active = 0 },

    pub inline fn end(self: *Zone) void {
        if (!enabled) return;
        if (self.ctx.active != 0) {
            yoke_tracy_zone_end(self.ctx);
            self.ctx.active = 0;
        }
    }

    pub inline fn text(self: Zone, txt: []const u8) void {
        if (!enabled) return;
        yoke_tracy_zone_text(self.ctx, txt.ptr, txt.len);
    }

    pub inline fn name(self: Zone, txt: []const u8) void {
        if (!enabled) return;
        yoke_tracy_zone_name(self.ctx, txt.ptr, txt.len);
    }

    pub inline fn color(self: Zone, color_value: u32) void {
        if (!enabled) return;
        yoke_tracy_zone_color(self.ctx, color_value);
    }

    pub inline fn value(self: Zone, value_u64: u64) void {
        if (!enabled) return;
        yoke_tracy_zone_value(self.ctx, value_u64);
    }
};

fn makeSourceLocation(
    comptime src: std.builtin.SourceLocation,
    comptime maybe_name: ?[:0]const u8,
    comptime color: u32,
) *const SourceLocation {
    return &struct {
        const data = SourceLocation{
            .name = if (maybe_name) |name| name.ptr else null,
            .function = src.fn_name.ptr,
            .file = src.file.ptr,
            .line = src.line,
            .color = color,
        };
    }.data;
}

pub inline fn zone() Zone {
    return zoneAt(@src());
}

pub inline fn zoneAt(comptime src: std.builtin.SourceLocation) Zone {
    if (!enabled) return .{};
    return .{
        .ctx = yoke_tracy_zone_begin(
            makeSourceLocation(src, @as(?[:0]const u8, null), 0),
            build_options.tracy_callstack_depth,
            1,
        ),
    };
}

pub inline fn zoneN(comptime name: [:0]const u8) Zone {
    return zoneNAt(name, @src());
}

pub inline fn zoneNAt(comptime name: [:0]const u8, comptime src: std.builtin.SourceLocation) Zone {
    if (!enabled) return .{};
    return .{
        .ctx = yoke_tracy_zone_begin(
            makeSourceLocation(src, name, 0),
            build_options.tracy_callstack_depth,
            1,
        ),
    };
}

pub inline fn zoneC(comptime color: u32) Zone {
    return zoneCAt(color, @src());
}

pub inline fn zoneCAt(comptime color: u32, comptime src: std.builtin.SourceLocation) Zone {
    if (!enabled) return .{};
    return .{
        .ctx = yoke_tracy_zone_begin(
            makeSourceLocation(src, @as(?[:0]const u8, null), color),
            build_options.tracy_callstack_depth,
            1,
        ),
    };
}

pub inline fn zoneNC(comptime name: [:0]const u8, comptime color: u32) Zone {
    return zoneNCAt(name, color, @src());
}

pub inline fn zoneNCAt(comptime name: [:0]const u8, comptime color: u32, comptime src: std.builtin.SourceLocation) Zone {
    if (!enabled) return .{};
    return .{
        .ctx = yoke_tracy_zone_begin(
            makeSourceLocation(src, name, color),
            build_options.tracy_callstack_depth,
            1,
        ),
    };
}

pub inline fn frameMark() void {
    if (!enabled) return;
    yoke_tracy_frame_mark(null);
}

pub inline fn frameMarkNamed(comptime name: [:0]const u8) void {
    if (!enabled) return;
    yoke_tracy_frame_mark(name.ptr);
}

pub inline fn setThreadName(name: [:0]const u8) void {
    if (!enabled) return;
    yoke_tracy_set_thread_name(name.ptr);
}

pub inline fn message(txt: []const u8) void {
    if (!enabled) return;
    yoke_tracy_message(txt.ptr, txt.len, 0);
}

pub inline fn messageC(txt: []const u8, color: u32) void {
    if (!enabled) return;
    yoke_tracy_message(txt.ptr, txt.len, color);
}

pub inline fn alloc(ptr: ?*const anyopaque, size: usize) void {
    if (!enabled) return;
    yoke_tracy_alloc(ptr, size);
}

pub inline fn free(ptr: ?*const anyopaque) void {
    if (!enabled) return;
    yoke_tracy_free(ptr);
}

pub inline fn startup() void {
    if (!enabled) return;
    if (!build_options.tracy_manual_lifetime) return;
    yoke_tracy_startup();
}

pub inline fn shutdown() void {
    if (!enabled) return;
    if (!build_options.tracy_manual_lifetime) return;
    yoke_tracy_shutdown();
}

