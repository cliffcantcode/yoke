const std = @import("std");
const abi = @import("abi.zig");

pub const Config = struct {
    module_name: []const u8 = "work_module.dll",
    shadow_a_name: []const u8 = "work_module_loaded_a.dll",
    shadow_b_name: []const u8 = "work_module_loaded_b.dll",
};

pub const Files = struct {
    dir: std.fs.Dir,
    dir_path: []const u8,

    pub fn init(allocator: std.mem.Allocator) !Files {
        const dir_path = try std.fs.selfExeDirPathAlloc(allocator);
        errdefer allocator.free(dir_path);

        return .{
            .dir = try std.fs.cwd().openDir(dir_path, .{}),
            .dir_path = dir_path,
        };
    }

    pub fn deinit(self: *Files, allocator: std.mem.Allocator) void {
        self.dir.close();
        allocator.free(self.dir_path);
    }

    pub fn fullPath(self: *const Files, buf: []u8, leaf: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "{s}{s}{s}", .{
            self.dir_path,
            std.fs.path.sep_str,
            leaf,
        });
    }
};

pub const LoadedModule = struct {
    lib: std.DynLib,
    api: *const abi.Api,

    pub fn close(self: *LoadedModule) void {
        self.lib.close();
    }
};

pub const Loader = struct {
    config: Config,
    files: Files,
    current_is_a: bool,
    current: LoadedModule,
    last_seen: std.fs.File.Stat,

    pub fn init(allocator: std.mem.Allocator, config: Config) !Loader {
        var files = try Files.init(allocator);
        errdefer files.deinit(allocator);

        return .{
            .config = config,
            .files = files,
            .current_is_a = true,
            .current = try loadModule(&files, config, config.shadow_a_name),
            .last_seen = try getModuleStamp(&files, config.module_name),
        };
    }

    pub fn deinit(self: *Loader, allocator: std.mem.Allocator) void {
        self.current.close();
        self.files.deinit(allocator);
    }

    pub fn maybeReload(self: *Loader) !bool {
        const newest = getModuleStamp(&self.files, self.config.module_name) catch |err| switch (err) {
            error.FileNotFound, error.AccessDenied => return false,
            else => return err,
        };

        if (sameStamp(newest, self.last_seen)) return false;

        const next_name = if (self.current_is_a)
            self.config.shadow_b_name
        else
            self.config.shadow_a_name;

        const next = loadModule(&self.files, self.config, next_name) catch |err| switch (err) {
            error.FileNotFound, error.AccessDenied => return false,
            else => return err,
        };

        self.current.close();
        self.current = next;
        self.current_is_a = !self.current_is_a;
        self.last_seen = newest;

        return true;
    }
};

fn loadModule(files: *const Files, config: Config, temp_name: []const u8) !LoadedModule {
    files.dir.deleteFile(temp_name) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };

    try files.dir.copyFile(config.module_name, files.dir, temp_name, .{});

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

fn getModuleStamp(files: *const Files, module_name: []const u8) !std.fs.File.Stat {
    var file = try files.dir.openFile(module_name, .{});
    defer file.close();
    return try file.stat();
}

fn sameStamp(a: std.fs.File.Stat, b: std.fs.File.Stat) bool {
    return a.size == b.size and a.mtime == b.mtime;
}

