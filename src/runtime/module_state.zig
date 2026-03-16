const std = @import("std");
const abi = @import("../abi.zig");

const BOOL = i32;
const DWORD = u32;

const MEM_COMMIT: DWORD = 0x00001000;
const MEM_RESERVE: DWORD = 0x00002000;
const MEM_RELEASE: DWORD = 0x00008000;
const PAGE_READWRITE: DWORD = 0x04;

extern "kernel32" fn VirtualAlloc(
    address: ?*anyopaque,
    size: usize,
    allocation_type: DWORD,
    protect: DWORD,
) callconv(.winapi) ?*anyopaque;

extern "kernel32" fn VirtualFree(
    address: ?*anyopaque,
    size: usize,
    free_type: DWORD,
) callconv(.winapi) BOOL;

pub const Config = struct {
    permanent_storage_size: u64 = 64 * 1024 * 1024,
    transient_storage_size: u64 = 256 * 1024 * 1024,
};

pub const Storage = struct {
    platform_memory: abi.PlatformMemory,

    pub fn init(config: Config) !Storage {
        return .{
            .platform_memory = .{
                .permanent_storage_size = config.permanent_storage_size,
                .permanent_storage = try allocRegion(config.permanent_storage_size),
                .transient_storage_size = config.transient_storage_size,
                .transient_storage = try allocRegion(config.transient_storage_size),
            },
        };
    }

    pub fn deinit(self: *Storage) void {
        freeRegion(self.platform_memory.permanent_storage);
        freeRegion(self.platform_memory.transient_storage);
    }

    pub fn memory(self: *Storage) *abi.PlatformMemory {
        return &self.platform_memory;
    }
};

fn allocRegion(size: u64) !*anyopaque {
    const alloc_size: usize = @intCast(if (size == 0) 1 else size);
    return VirtualAlloc(null, alloc_size, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE) orelse
        error.VirtualAllocFailed;
}

fn freeRegion(address: *anyopaque) void {
    if (VirtualFree(address, 0, MEM_RELEASE) == 0) {
        @panic("VirtualFree failed");
    }
}

