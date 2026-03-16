const std = @import("std");
const abi = @import("abi.zig");
const hot_reload = @import("runtime/hot_reload.zig");
const module_state = @import("runtime/module_state.zig");

const BOOL = i32;
const UINT = u32;
const WORD = u16;
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
const HDC = HANDLE;

const WM_MOUSEMOVE: UINT = 0x0200;
const WM_LBUTTONDOWN: UINT = 0x0201;
const WM_LBUTTONUP: UINT = 0x0202;
const WM_KEYDOWN: UINT = 0x0100;
const WM_KEYUP: UINT = 0x0101;
const WM_SYSKEYDOWN: UINT = 0x0104;
const WM_SYSKEYUP: UINT = 0x0105;
const WM_DESTROY: UINT = 0x0002;
const WM_QUIT: UINT = 0x0012;
const PM_REMOVE: UINT = 0x0001;

const VK_ESCAPE: UINT = 0x1B;
const VK_SPACE: UINT = 0x20;

const BI_RGB: DWORD = 0;
const DIB_RGB_COLORS: UINT = 0;
const SRCCOPY: DWORD = 0x00CC0020;
const ERROR_CLASS_ALREADY_EXISTS: u32 = 1410;

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

const WM_SETCURSOR: UINT = 0x0020;
const HTCLIENT: u16 = 1;

const IDC_ARROW_ID: u16 = 32512;
const IDC_SIZEALL_ID: u16 = 32646;
const IDC_HAND_ID: u16 = 32649;

extern "user32" fn LoadCursorA(instance: HINSTANCE, cursor_name: ?[*:0]const u8) callconv(.winapi) HCURSOR;
extern "user32" fn SetCursor(cursor: HCURSOR) callconv(.winapi) HCURSOR;

const permanent_storage_size: u64 = 64 * 1024 * 1024;
const transient_storage_size: u64 = 256 * 1024 * 1024;

const update_hz: u32 = 60;
const render_hz: u32 = 60;
const max_frame_ns: u64 = 250 * std.time.ns_per_ms;
const max_catchup_updates: u32 = 8;
const max_render_commands = 1024;

const POINT = extern struct {
    x: LONG,
    y: LONG,
};

const RECT = extern struct {
    left: LONG,
    top: LONG,
    right: LONG,
    bottom: LONG,
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

const RGBQUAD = extern struct {
    rgbBlue: u8,
    rgbGreen: u8,
    rgbRed: u8,
    rgbReserved: u8,
};

const BITMAPINFOHEADER = extern struct {
    biSize: DWORD,
    biWidth: LONG,
    biHeight: LONG,
    biPlanes: WORD,
    biBitCount: WORD,
    biCompression: DWORD,
    biSizeImage: DWORD,
    biXPelsPerMeter: LONG,
    biYPelsPerMeter: LONG,
    biClrUsed: DWORD,
    biClrImportant: DWORD,
};

const BITMAPINFO = extern struct {
    bmiHeader: BITMAPINFOHEADER,
    bmiColors: [1]RGBQUAD,
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
    lpszClassName: [*:0]const u8,
};

extern "kernel32" fn GetModuleHandleA(name: ?[*:0]const u8) callconv(.winapi) HINSTANCE;
extern "kernel32" fn GetLastError() callconv(.winapi) u32;
extern "kernel32" fn QueryPerformanceCounter(performance_count: *i64) callconv(.winapi) i32;
extern "kernel32" fn QueryPerformanceFrequency(frequency: *i64) callconv(.winapi) i32;

extern "user32" fn RegisterClassA(wnd_class: *const WNDCLASSA) callconv(.winapi) ATOM;
extern "user32" fn CreateWindowExA(
    ex_style: DWORD,
    class_name: [*:0]const u8,
    window_name: [*:0]const u8,
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
extern "user32" fn GetClientRect(hwnd: HWND, rect: *RECT) callconv(.winapi) BOOL;
extern "user32" fn GetDC(hwnd: HWND) callconv(.winapi) HDC;
extern "user32" fn ReleaseDC(hwnd: HWND, hdc: HDC) callconv(.winapi) INT;
extern "user32" fn SetCapture(hwnd: HWND) callconv(.winapi) HWND;
extern "user32" fn ReleaseCapture() callconv(.winapi) BOOL;

extern "gdi32" fn StretchDIBits(
    hdc: HDC,
    x_dest: INT,
    y_dest: INT,
    dest_width: INT,
    dest_height: INT,
    x_src: INT,
    y_src: INT,
    src_width: INT,
    src_height: INT,
    bits: ?*const anyopaque,
    bits_info: *const BITMAPINFO,
    usage: UINT,
    rop: DWORD,
) callconv(.winapi) INT;

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

const HostButtonState = struct {
    is_down: bool = false,
    changed: bool = false,
};

const HostInputState = struct {
    quit_requested: bool = false,
    mouse_x_win32: i32 = 0,
    mouse_y_win32: i32 = 0,
    escape: HostButtonState = .{},
    space: HostButtonState = .{},
    mouse_left: HostButtonState = .{},
};

var g_input_state: HostInputState = .{};
var g_cursors: CursorSet = undefined;
var g_current_cursor_kind: abi.CursorKind = .arrow;

const CursorSet = struct {
    arrow: HCURSOR,
    hand: HCURSOR,
    size_all: HCURSOR,
};

fn makeIntResourceA(id: u16) [*:0]const u8 {
    return @ptrFromInt(id);
}

fn loadSystemCursor(id: u16) !HCURSOR {
    return LoadCursorA(null, makeIntResourceA(id)) orelse error.LoadCursorFailed;
}

fn initCursors() !void {
    g_cursors = .{
        .arrow = try loadSystemCursor(IDC_ARROW_ID),
        .hand = try loadSystemCursor(IDC_HAND_ID),
        .size_all = try loadSystemCursor(IDC_SIZEALL_ID),
    };
}

fn applyCursor(kind: abi.CursorKind) void {
    const cursor = switch (kind) {
        .arrow => g_cursors.arrow,
        .hand => g_cursors.hand,
        .size_all => g_cursors.size_all,
    };
    _ = SetCursor(cursor);
}

fn setDesiredCursor(kind: abi.CursorKind) void {
    g_current_cursor_kind = kind;
    applyCursor(kind);
}

fn lowU16(l_param: LPARAM) u16 {
    const raw: usize = @bitCast(l_param);
    return @truncate(raw);
}

const Win32Backbuffer = struct {
    info: BITMAPINFO = .{
        .bmiHeader = .{
            .biSize = @intCast(@sizeOf(BITMAPINFOHEADER)),
            .biWidth = 0,
            .biHeight = 0,
            .biPlanes = 1,
            .biBitCount = 32,
            .biCompression = BI_RGB,
            .biSizeImage = 0,
            .biXPelsPerMeter = 0,
            .biYPelsPerMeter = 0,
            .biClrUsed = 0,
            .biClrImportant = 0,
        },
        .bmiColors = [_]RGBQUAD{.{
            .rgbBlue = 0,
            .rgbGreen = 0,
            .rgbRed = 0,
            .rgbReserved = 0,
        }},
    },

    memory: []align(@alignOf(u32)) u8 = &.{},
    width: u32 = 0,
    height: u32 = 0,
    pitch: u32 = 0,
    bytes_per_pixel: u32 = 4,

    fn deinit(self: *Win32Backbuffer, allocator: std.mem.Allocator) void {
        if (self.memory.len != 0) {
            allocator.free(self.memory);
            self.memory = &.{};
        }
    }

    fn resize(self: *Win32Backbuffer, allocator: std.mem.Allocator, width: u32, height: u32) !void {
        if (self.width == width and self.height == height) return;

        if (self.memory.len != 0) {
            allocator.free(self.memory);
            self.memory = &.{};
        }

        self.width = width;
        self.height = height;
        self.pitch = width * self.bytes_per_pixel;

        if (width == 0 or height == 0) {
            self.info.bmiHeader.biWidth = 0;
            self.info.bmiHeader.biHeight = 0;
            self.info.bmiHeader.biSizeImage = 0;
            return;
        }

        const size = @as(usize, width) * @as(usize, height) * @as(usize, self.bytes_per_pixel);
        self.memory = try allocator.alignedAlloc(u8, .fromByteUnits(@alignOf(u32)), size);
        @memset(self.memory, 0);

        self.info.bmiHeader.biWidth = @as(LONG, @intCast(width));
        self.info.bmiHeader.biHeight = @as(LONG, @intCast(height));
        self.info.bmiHeader.biSizeImage = @intCast(size);
    }
};

fn backbufferClear(buffer: *Win32Backbuffer, color: u32) void {
    var y: u32 = 0;
    while (y < buffer.height) : (y += 1) {
        const row_base = buffer.memory.ptr + @as(usize, y) * @as(usize, buffer.pitch);
        const row: [*]u32 = @ptrCast(@alignCast(row_base));
        var x: u32 = 0;
        while (x < buffer.width) : (x += 1) {
            row[x] = color;
        }
    }
}

fn backbufferFillRect(buffer: *Win32Backbuffer, x0_in: i32, y0_in: i32, x1_in: i32, y1_in: i32, color: u32) void {
    const max_x: i32 = @intCast(buffer.width);
    const max_y: i32 = @intCast(buffer.height);

    const x0 = std.math.clamp(x0_in, 0, max_x);
    const y0 = std.math.clamp(y0_in, 0, max_y);
    const x1 = std.math.clamp(x1_in, 0, max_x);
    const y1 = std.math.clamp(y1_in, 0, max_y);

    if (x0 >= x1 or y0 >= y1) return;

    var y = y0;
    while (y < y1) : (y += 1) {
        const row_base = buffer.memory.ptr + @as(usize, @intCast(y)) * @as(usize, buffer.pitch);
        const row: [*]u32 = @ptrCast(@alignCast(row_base));
        var x = x0;
        while (x < x1) : (x += 1) {
            row[@as(usize, @intCast(x))] = color;
        }
    }
}

fn backbufferStrokeRect(
    buffer: *Win32Backbuffer,
    x0_in: i32,
    y0_in: i32,
    x1_in: i32,
    y1_in: i32,
    thickness_in: i32,
    color: u32,
) void {
    const t = @max(thickness_in, 1);

    backbufferFillRect(buffer, x0_in, y0_in, x1_in, y0_in + t, color); // bottom
    backbufferFillRect(buffer, x0_in, y1_in - t, x1_in, y1_in, color); // top
    backbufferFillRect(buffer, x0_in, y0_in + t, x0_in + t, y1_in - t, color); // left
    backbufferFillRect(buffer, x1_in - t, y0_in + t, x1_in, y1_in - t, color); // right
}

fn executeRenderCommands(buffer: *Win32Backbuffer, frame: *const abi.Frame) void {
    var i: u32 = 0;
    while (i < frame.command_buffer.count) : (i += 1) {
        const cmd = frame.command_buffer.commands[i];
        const kind: abi.RenderCommandKind = @enumFromInt(cmd.kind);
        switch (kind) {
            .clear => backbufferClear(buffer, cmd.color),
            .fill_rect => backbufferFillRect(
                buffer,
                @intFromFloat(cmd.x0),
                @intFromFloat(cmd.y0),
                @intFromFloat(cmd.x1),
                @intFromFloat(cmd.y1),
                cmd.color,
            ),
            .stroke_rect => {
                const thickness = @max(1, @as(i32, @intFromFloat(cmd.thickness)));
                backbufferStrokeRect(
                    buffer,
                    @intFromFloat(cmd.x0),
                    @intFromFloat(cmd.y0),
                    @intFromFloat(cmd.x1),
                    @intFromFloat(cmd.y1),
                    thickness,
                    cmd.color,
                );
            },
        }
    }
}

fn presentBackbuffer(window: HWND, buffer: *const Win32Backbuffer) !void {
    if (buffer.memory.len == 0) return;

    const dc = GetDC(window) orelse return error.GetDCFailed;
    defer _ = ReleaseDC(window, dc);

    _ = StretchDIBits(
        dc,
        0,
        0,
        @intCast(buffer.width),
        @intCast(buffer.height),
        0,
        0,
        @intCast(buffer.width),
        @intCast(buffer.height),
        @ptrCast(buffer.memory.ptr),
        &buffer.info,
        DIB_RGB_COLORS,
        SRCCOPY,
    );
}

fn updateButton(button: *HostButtonState, is_down: bool) void {
    if (button.is_down != is_down) {
        button.is_down = is_down;
        button.changed = true;
    }
}

fn handleVirtualKey(vk: UINT, is_down: bool) void {
    switch (vk) {
        VK_ESCAPE => updateButton(&g_input_state.escape, is_down),
        VK_SPACE => updateButton(&g_input_state.space, is_down),
        else => {},
    }
}

fn lowS16(l_param: LPARAM) i16 {
    const raw: usize = @bitCast(l_param);
    return @bitCast(@as(u16, @truncate(raw)));
}

fn highS16(l_param: LPARAM) i16 {
    const raw: usize = @bitCast(l_param);
    return @bitCast(@as(u16, @truncate(raw >> 16)));
}

fn clearInputTransitions() void {
    g_input_state.escape.changed = false;
    g_input_state.space.changed = false;
    g_input_state.mouse_left.changed = false;
}

fn snapshotInput(window: HWND) !abi.Input {
    var rect: RECT = undefined;
    if (GetClientRect(window, &rect) == 0) {
        return error.GetClientRectFailed;
    }

    const width_i32: i32 = if (rect.right > rect.left) rect.right - rect.left else 0;
    const height_i32: i32 = if (rect.bottom > rect.top) rect.bottom - rect.top else 0;

    const max_x = @max(width_i32 - 1, 0);
    const max_y = @max(height_i32 - 1, 0);

    const clamped_x = std.math.clamp(g_input_state.mouse_x_win32, 0, max_x);
    const clamped_y_top = std.math.clamp(g_input_state.mouse_y_win32, 0, max_y);
    const y_bottom: i32 = if (height_i32 > 0) height_i32 - 1 - clamped_y_top else 0;

    return .{
        .quit_requested = @intFromBool(g_input_state.quit_requested),
        .client_width = @intCast(width_i32),
        .client_height = @intCast(height_i32),
        .mouse_x = @as(f32, @floatFromInt(clamped_x)),
        .mouse_y = @as(f32, @floatFromInt(y_bottom)),
        .escape = .{
            .is_down = @intFromBool(g_input_state.escape.is_down),
            .changed = @intFromBool(g_input_state.escape.changed),
        },
        .space = .{
            .is_down = @intFromBool(g_input_state.space.is_down),
            .changed = @intFromBool(g_input_state.space.changed),
        },
        .mouse_left = .{
            .is_down = @intFromBool(g_input_state.mouse_left.is_down),
            .changed = @intFromBool(g_input_state.mouse_left.changed),
        },
    };
}

fn windowProc(hwnd: HWND, msg: UINT, w_param: WPARAM, l_param: LPARAM) callconv(.winapi) LRESULT {
    switch (msg) {
        WM_DESTROY => {
            g_input_state.quit_requested = true;
            PostQuitMessage(0);
            return 0;
        },
        WM_KEYDOWN, WM_SYSKEYDOWN => {
            handleVirtualKey(@intCast(w_param), true);
            return 0;
        },
        WM_KEYUP, WM_SYSKEYUP => {
            handleVirtualKey(@intCast(w_param), false);
            return 0;
        },
        WM_MOUSEMOVE => {
            g_input_state.mouse_x_win32 = lowS16(l_param);
            g_input_state.mouse_y_win32 = highS16(l_param);
            return 0;
        },
        WM_LBUTTONDOWN => {
            g_input_state.mouse_x_win32 = lowS16(l_param);
            g_input_state.mouse_y_win32 = highS16(l_param);
            updateButton(&g_input_state.mouse_left, true);
            _ = SetCapture(hwnd);
            return 0;
        },
        WM_LBUTTONUP => {
            g_input_state.mouse_x_win32 = lowS16(l_param);
            g_input_state.mouse_y_win32 = highS16(l_param);
            updateButton(&g_input_state.mouse_left, false);
            _ = ReleaseCapture();
            return 0;
        },
        WM_SETCURSOR => {
            if (lowU16(l_param) == HTCLIENT or g_input_state.mouse_left.is_down) {
                applyCursor(g_current_cursor_kind);
                return 1;
            }
            return DefWindowProcA(hwnd, msg, w_param, l_param);
        },
        else => return DefWindowProcA(hwnd, msg, w_param, l_param),
    }
}

fn createMainWindow() !HWND {
    const class_name: [*:0]const u8 = "YokeWindowClass";
    const window_title: [*:0]const u8 = "yoke_win32";

    const instance = GetModuleHandleA(null) orelse return error.GetModuleHandleFailed;

    const wnd_class = WNDCLASSA{
        .style = 0,
        .lpfnWndProc = &windowProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = instance,
        .hIcon = null,
        .hCursor = g_cursors.arrow,
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = class_name,
    };

    if (RegisterClassA(&wnd_class) == 0) {
        const err = GetLastError();
        if (err != ERROR_CLASS_ALREADY_EXISTS) {
            return error.RegisterClassFailed;
        }
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
    ) orelse return error.CreateWindowFailed;

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

fn validateModuleMemory(loader: *const hot_reload.Loader, storage: *module_state.Storage) !void {
    const memory = storage.memory();

    if (loader.current.api.required_permanent_storage_size > memory.permanent_storage_size) {
        return error.PermanentStorageTooSmall;
    }

    if (loader.current.api.required_transient_storage_size > memory.transient_storage_size) {
        return error.TransientStorageTooSmall;
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var clock = try Clock.init();
    var loader = try hot_reload.Loader.init(allocator, .{});
    defer loader.deinit(allocator);

    var storage = try module_state.Storage.init(.{
        .permanent_storage_size = permanent_storage_size,
        .transient_storage_size = transient_storage_size,
    });
    defer storage.deinit();

    try validateModuleMemory(&loader, &storage);
    loader.current.api.init(storage.memory());

    var backbuffer = Win32Backbuffer{};
    defer backbuffer.deinit(allocator);

    try initCursors();

    const window = try createMainWindow();

    const update_step_ns: u64 = std.time.ns_per_s / update_hz;
    const render_step_ns: u64 = std.time.ns_per_s / render_hz;

    var last_ticks = try clock.nowTicks();
    var update_accum: u64 = 0;
    var render_accum: u64 = 0;
    var update_tick: u64 = 0;
    var render_tick: u64 = 0;
    var render_commands: [max_render_commands]abi.RenderCommand = undefined;

    std.debug.print(
        "yoke windows platform layer | update={d}Hz render={d}Hz | watching {s}\n",
        .{ update_hz, render_hz, loader.config.module_name },
    );

    while (true) {
        if (!pumpMessages()) break;

        const now_ticks = try clock.nowTicks();
        var frame_ns = clock.deltaNs(last_ticks, now_ticks);
        last_ticks = now_ticks;
        frame_ns = @min(frame_ns, max_frame_ns);

        if (try loader.maybeReload()) {
            try validateModuleMemory(&loader, &storage);
            loader.current.api.on_reload(storage.memory());
            std.debug.print("Reloaded {s}\n", .{loader.config.module_name});
        }

        const frame_input = try snapshotInput(window);
        try backbuffer.resize(allocator, frame_input.client_width, frame_input.client_height);

        update_accum += frame_ns;
        render_accum += frame_ns;

        var caught_up: u32 = 0;
        var update_input = frame_input;

        while (update_accum >= update_step_ns and caught_up < max_catchup_updates) : (caught_up += 1) {
            update_tick += 1;
            loader.current.api.update(storage.memory(), .{
                .dt_ns = update_step_ns,
                .tick_index = update_tick,
                .input = update_input,
            });

            update_input.escape.changed = 0;
            update_input.space.changed = 0;
            update_input.mouse_left.changed = 0;

            update_accum -= update_step_ns;
        }

        if (caught_up == max_catchup_updates and update_accum >= update_step_ns) {
            update_accum %= update_step_ns;
        }

        if (render_accum >= render_step_ns and backbuffer.memory.len != 0) {
            render_tick += 1;

            var render_input = frame_input;
            render_input.escape.changed = 0;
            render_input.space.changed = 0;
            render_input.mouse_left.changed = 0;

            var frame = abi.Frame{
                .target = .{
                    .width = backbuffer.width,
                    .height = backbuffer.height,
                },
                .command_buffer = .{
                    .commands = &render_commands,
                    .count = 0,
                    .capacity = render_commands.len,
                },
                .cursor_kind = @intFromEnum(abi.CursorKind.arrow),
            };

            loader.current.api.render(storage.memory(), .{
                .dt_ns = render_step_ns,
                .tick_index = render_tick,
                .input = render_input,
            }, &frame);

            setDesiredCursor(@enumFromInt(frame.cursor_kind));

            executeRenderCommands(&backbuffer, &frame);
            try presentBackbuffer(window, &backbuffer);
            render_accum %= render_step_ns;
        }

        clearInputTransitions();

        const until_update = update_step_ns - update_accum;
        const until_render = render_step_ns - render_accum;
        const sleep_ns = @min(until_update, until_render);

        if (sleep_ns > 250 * std.time.ns_per_us) {
            std.Thread.sleep(sleep_ns / 2);
        }
    }
}

