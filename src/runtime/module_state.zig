const std = @import("std");
const abi = @import("../abi.zig");

pub const Storage = struct {
    memory: []align(abi.module_state_alignment) u8 = &.{},
    logical_size: u32 = 0,

    pub fn deinit(self: *Storage, allocator: std.mem.Allocator) void {
        if (self.memory.len != 0) {
            allocator.free(self.memory);
            self.memory = &.{};
        }
        self.logical_size = 0;
    }

    pub fn ensureSize(self: *Storage, allocator: std.mem.Allocator, size: u32) !bool {
        if (self.logical_size == size and self.memory.len != 0) return false;

        if (self.memory.len != 0) {
            allocator.free(self.memory);
            self.memory = &.{};
        }

        const alloc_size: usize = if (size == 0) 1 else size;

        self.memory = try allocator.alignedAlloc(
            u8,
            .fromByteUnits(abi.module_state_alignment),
            alloc_size,
        );
        @memset(self.memory, 0);
        self.logical_size = size;
        return true;
    }

    pub fn ptr(self: *Storage) *anyopaque {
        return @ptrCast(self.memory.ptr);
    }
};

