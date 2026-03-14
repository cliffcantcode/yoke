const std = @import("std");
const abi = @import("abi.zig");

const BOOL = i32;
const UINT = u32;
const DWORD = u32;
const INT = i32;
const LONG = i32;
const LPARAM = isize;
const WPARAM = usize;
const LRESULT = isize;
const ATOM = u16;

const HANDLE = ?*anyopaque;
const HINSTANCE = HANDLE;
const HWND = HANDLE;
const HMENU = HANDLE;
const HICON = HANDLE;
const HCURSOR = HANDLE;
const HBRUSH = HANDLE;

const POINT = extern struct {
    x: LONG,
    y: LONG,
};

const MSG = extern struct {
    hwnd: HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
    lPrivate: DWORD,
};

const WNDPROC = *const fn (
    hwnd: HWND,
    msg: UINT,
    w_param: WPARAM,
    l_param: LPARAM,
) callconv(.winapi) LRESULT;

const WNDCLASSA = extern struct {
    style: UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: INT,
    cbWndExtra: INT,
    hInstance: HINSTANCE,
    hIcon: HICON,
    hCursor: HCURSOR,
    hbrBackground: HBRUSH,
    lpszMenuName: ?[*:0]const u8,
    lpszClassName: ?[*:0]const u8,
};

extern "kernel32" fn GetModuleHandleA(name: ?[*:0]const u8) callconv(.winapi) HINSTANCE;
extern "kernel32" fn GetLastError() callconv(.winapi) u32;

extern "user32" fn RegisterClassA(wnd_class: *const WNDCLASSA) callconv(.winapi) ATOM;
extern "user32" fn CreateWindowExA(
    ex_style: DWORD,
    class_name: ?[*:0]const u8,
    window_name: ?[*:0]const u8,
    style: DWORD,
    x: INT,
    y: INT,
    width: INT,
    height: INT,
    parent: HWND,
    menu: HMENU,
    instance: HINSTANCE,
    param: ?*anyopaque,
) callconv(.winapi) HWND;
extern "user32" fn ShowWindow(hwnd: HWND, cmd_show: INT) callconv(.winapi) BOOL;
extern "user32" fn UpdateWindow(hwnd: HWND) callconv(.winapi) BOOL;
extern "user32" fn PeekMessageA(
    msg: *MSG,
    hwnd: HWND,
    min_filter: UINT,
    max_filter: UINT,
    remove_msg: UINT,
) callconv(.winapi) BOOL;
extern "user32" fn TranslateMessage(msg: *const MSG) callconv(.winapi) BOOL;
extern "user32" fn DispatchMessageA(msg: *const MSG) callconv(.winapi) LRESULT;
extern "user32" fn DefWindowProcA(
    hwnd: HWND,
    msg: UINT,
    w_param: WPARAM,
    l_param: LPARAM,
) callconv(.winapi) LRESULT;
extern "user32" fn PostQuitMessage(exit_code: INT) callconv(.winapi) void;

const WM_DESTROY: UINT = 0x0002;
const WM_QUIT: UINT = 0x0012;
const PM_REMOVE: UINT = 0x0001;

const WS_OVERLAPPED: DWORD = 0x00000000;
const WS_CAPTION: DWORD = 0x00C00000;
const WS_SYSMENU: DWORD = 0x00080000;
const WS_THICKFRAME: DWORD = 0x00040000;
const WS_MINIMIZEBOX: DWORD = 0x00020000;
const WS_MAXIMIZEBOX: DWORD = 0x00010000;
const WS_VISIBLE: DWORD = 0x10000000;
const WS_OVERLAPPEDWINDOW: DWORD =
    WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;

const SW_SHOW: INT = 5;
const CW_USEDEFAULT: INT = @as(INT, @bitCast(@as(u32, 0x80000000)));
const ERROR_CLASS_ALREADY_EXISTS: u32 = 1410;

extern "kernel32" fn QueryPerformanceCounter(performance_count: *i64) callconv(.winapi) i32;
extern "kernel32" fn QueryPerformanceFrequency(frequency: *i64) callconv(.winapi) i32;

const module_name = "work_module.dll";
const loaded_a_name = "work_module_loaded_a.dll";
const loaded_b_name = "work_module_loaded_b.dll";

const update_hz: u32 = 60;
const render_hz: u32 = 60;

const max_frame_ns: u64 = 250 * std.time.ns_per_ms;
const max_catchup_updates: u32 = 8;

fn windowProc(hwnd: HWND, msg: UINT, w_param: WPARAM, l_param: LPARAM) callconv(.winapi) LRESULT {
    switch (msg) {
        WM_DESTROY => {
            PostQuitMessage(0);
            return 0;
        },
        else => return DefWindowProcA(hwnd, msg, w_param, l_param),
    }
}

fn createMainWindow() !HWND {
    const class_name = "YokeWindowClass";
    const window_title = "yoke";

    const instance = GetModuleHandleA(null) orelse return error.GetModuleHandleFailed;

    const wnd_class = WNDCLASSA{
        .style = 0,
        .lpfnWndProc = &windowProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = instance,
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = class_name,
    };

    if (RegisterClassA(&wnd_class) == 0) {
        return error.RegisterClassFailed;
    }

    const hwnd = CreateWindowExA(
        0,
        class_name,
        window_title,
        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        1280,
        720,
        null,
        null,
        instance,
        null,
    ) orelse {
        std.debug.print("CreateWindowExA failed: {d}\n", .{GetLastError()});
        return error.CreateWindowFailed;
    };

    _ = ShowWindow(hwnd, SW_SHOW);
    _ = UpdateWindow(hwnd);

    return hwnd;
}

fn pumpMessages() bool {
    var msg: MSG = undefined;

    while (PeekMessageA(&msg, null, 0, 0, PM_REMOVE) != 0) {
        if (msg.message == WM_QUIT) return false;
        _ = TranslateMessage(&msg);
        _ = DispatchMessageA(&msg);
    }

    return true;
}

const ModuleFiles = struct {
    dir: std.fs.Dir,
    dir_path: []const u8,

    fn init(allocator: std.mem.Allocator) !ModuleFiles {
        const dir_path = try std.fs.selfExeDirPathAlloc(allocator);
        errdefer allocator.free(dir_path);

        return .{
            .dir = try std.fs.cwd().openDir(dir_path, .{}),
            .dir_path = dir_path,
        };
    }

    fn deinit(self: *ModuleFiles, allocator: std.mem.Allocator) void {
        self.dir.close();
        allocator.free(self.dir_path);
    }

    fn fullPath(self: *const ModuleFiles, buf: []u8, leaf: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "{s}{s}{s}", .{
            self.dir_path,
            std.fs.path.sep_str,
            leaf,
        });
    }
};

const Clock = struct {
    freq: u64,

    fn init() !Clock {
        var freq: i64 = 0;
        if (QueryPerformanceFrequency(&freq) == 0 or freq <= 0) {
            return error.QueryPerformanceFrequencyFailed;
        }
        return .{ .freq = @as(u64, @intCast(freq)) };
    }

    fn nowTicks(_: *const Clock) !u64 {
        var ticks: i64 = 0;
        if (QueryPerformanceCounter(&ticks) == 0 or ticks < 0) {
            return error.QueryPerformanceCounterFailed;
        }
        return @as(u64, @intCast(ticks));
    }

    fn deltaNs(self: *const Clock, earlier: u64, later: u64) u64 {
        const delta_ticks = later - earlier;
        return @as(u64, @intCast((@as(u128, delta_ticks) * std.time.ns_per_s) / self.freq));
    }
};

const LoadedModule = struct {
    lib: std.DynLib,
    api: *const abi.Api,
    fn close(self: *LoadedModule) void {
        self.lib.close();
    }
};

const ModuleLoader = struct {
    files: ModuleFiles,
    current_is_a: bool,
    current: LoadedModule,
    last_seen: std.fs.File.Stat,

    fn init(allocator: std.mem.Allocator) !ModuleLoader {
        var files = try ModuleFiles.init(allocator);
        errdefer files.deinit(allocator);

        return .{
            .files = files,
            .current_is_a = true,
            .current = try loadModule(&files, loaded_a_name),
            .last_seen = try getModuleStamp(&files),
        };
    }

    fn deinit(self: *ModuleLoader, allocator: std.mem.Allocator) void {
        self.current.close();
        self.files.deinit(allocator);
    }

    fn maybeReload(self: *ModuleLoader, state: *abi.State) !void {
        const newest = getModuleStamp(&self.files) catch |err| switch (err) {
            error.FileNotFound, error.AccessDenied => return,
            else => return err,
        };

        if (sameStamp(newest, self.last_seen)) return;

        const next_name = if (self.current_is_a) loaded_b_name else loaded_a_name;

        const next = loadModule(&self.files, next_name) catch |err| switch (err) {
            error.FileNotFound, error.AccessDenied => return,
            else => return err,
        };

        self.current.close();
        self.current = next;
        self.current_is_a = !self.current_is_a;
        self.last_seen = newest;

        self.current.api.on_reload(state);
        std.debug.print("reloaded {s}\n", .{module_name});
    }
};

fn loadModule(files: *const ModuleFiles, temp_name: []const u8) !LoadedModule {
    files.dir.deleteFile(temp_name) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };

    try files.dir.copyFile(module_name, files.dir, temp_name, .{});

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const temp_path = try files.fullPath(&path_buf, temp_name);

    var lib = try std.DynLib.open(temp_path);
    errdefer lib.close();

    const get_api = lib.lookup(abi.GetApiFn, abi.symbols.get_api) orelse
        return error.MissingSymbol;

    const api = get_api();
    if (api.abi_version != abi.abi_version) {
        return error.IncompatibleAbi;
    }

    return .{
        .lib = lib,
        .api = api,
    };
}

fn getModuleStamp(files: *const ModuleFiles) !std.fs.File.Stat {
    var file = try files.dir.openFile(module_name, .{});
    defer file.close();
    return try file.stat();
}

fn sameStamp(a: std.fs.File.Stat, b: std.fs.File.Stat) bool {
    return a.size == b.size and a.mtime == b.mtime;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var clock = try Clock.init();
    var loader = try ModuleLoader.init(allocator);
    defer loader.deinit(allocator);

    var state: abi.State = .{};
    loader.current.api.init(&state);

    const window = try createMainWindow();
    _ = window;

    const update_step_ns: u64 = std.time.ns_per_s / update_hz;
    const render_step_ns: u64 = std.time.ns_per_s / render_hz;

    var last_ticks = try clock.nowTicks();
    var update_accum: u64 = 0;
    var render_accum: u64 = 0;
    var update_tick: u64 = 0;
    var render_tick: u64 = 0;

    std.debug.print(
        "yoke windows platform layer | update={d}Hz render={d}Hz | watching {s}\n",
        .{ update_hz, render_hz, module_name },
    );

    while (true) {
        if (!pumpMessages()) break;

        const now_ticks = try clock.nowTicks();
        var frame_ns = clock.deltaNs(last_ticks, now_ticks);
        last_ticks = now_ticks;

        frame_ns = @min(frame_ns, max_frame_ns);

        try loader.maybeReload(&state);

        update_accum += frame_ns;
        render_accum += frame_ns;

        var caught_up: u32 = 0;
        while (update_accum >= update_step_ns and caught_up < max_catchup_updates) : (caught_up += 1) {
            update_tick += 1;
            loader.current.api.update(&state, .{
                .dt_ns = update_step_ns,
                .tick_index = update_tick,
            });
            update_accum -= update_step_ns;
        }

        if (caught_up == max_catchup_updates and update_accum >= update_step_ns) {
            update_accum %= update_step_ns;
        }

        if (render_accum >= render_step_ns) {
            render_tick += 1;
            loader.current.api.render(&state, .{
                .dt_ns = render_step_ns,
                .tick_index = render_tick,
            });
            render_accum %= render_step_ns;
        }

        const until_update = update_step_ns - update_accum;
        const until_render = render_step_ns - render_accum;
        const sleep_ns = @min(until_update, until_render);

        if (sleep_ns > 250 * std.time.ns_per_us) {
            std.Thread.sleep(sleep_ns / 2);
        }
    }
}

