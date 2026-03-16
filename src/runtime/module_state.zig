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

extern "kernel32" fn GetLastError() callconv(.winapi) DWORD;

pub const Config = struct {
    permanent_storage_size: u64 = 64 * 1024 * 1024,
    transient_storage_size: u64 = 256 * 1024 * 1024,
};

pub const Storage = struct {
    base_address: ?*anyopaque,
    total_size: u64,
    transient_offset: u64,
    platform_memory: abi.PlatformMemory,

    pub fn init(config: Config) !Storage {
        const alignment: u64 = abi.module_state_alignment;

        const permanent_aligned = alignForwardU64(config.permanent_storage_size, alignment);
        const transient_offset = permanent_aligned;

        const total_size_u64 = blk: {
            const raw = permanent_aligned + config.transient_storage_size;
            break :blk if (raw == 0) 1 else raw;
        };

        const total_size: usize = @intCast(total_size_u64);

        const base = VirtualAlloc(
            null,
            total_size,
            MEM_RESERVE | MEM_COMMIT,
            PAGE_READWRITE,
        ) orelse return error.VirtualAllocFailed;

        const base_bytes: [*]align(abi.module_state_alignment) u8 = @ptrCast(@alignCast(base));

        const permanent_storage: *anyopaque = @ptrCast(base_bytes);

        const transient_storage: *anyopaque = if (config.transient_storage_size == 0)
            @ptrCast(base_bytes)
        else
            @ptrCast(base_bytes + @as(usize, @intCast(transient_offset)));

        return .{
            .base_address = base,
            .total_size = total_size_u64,
            .transient_offset = transient_offset,
            .platform_memory = .{
                .permanent_storage_size = config.permanent_storage_size,
                .permanent_storage = permanent_storage,
                .transient_storage_size = config.transient_storage_size,
                .transient_storage = transient_storage,
            },
        };
    }

    pub fn deinit(self: *Storage) void {
        if (self.base_address) |base| {
            if (VirtualFree(base, 0, MEM_RELEASE) == 0) {
                const err = GetLastError();
                std.debug.print("VirtualFree failed, GetLastError={d}\n", .{err});
                @panic("VirtualFree failed");
            }
            self.base_address = null;
        }
    }

    pub fn memory(self: *Storage) *abi.PlatformMemory {
        return &self.platform_memory;
    }
};

fn alignForwardU64(value: u64, alignment: u64) u64 {
    std.debug.assert(alignment != 0);
    const mask = alignment - 1;
    return (value + mask) & ~mask;
}

