const std = @import("std");

pub const FieldByteLayout = struct {
    name: []const u8,
    source_index: usize,
    offset: usize,
    size: usize,
    end: usize,
    alignment: usize,
    is_comptime: bool,
};

pub const ByteLayoutStats = struct {
    size: usize,
    alignment: usize,
    field_count: usize,
    field_bytes: usize,
    internal_padding_bytes: usize,
    trailing_padding_bytes: usize,
    total_padding_bytes: usize,

    pub fn hasPadding(self: @This()) bool {
        return self.total_padding_bytes != 0;
    }

    pub fn hasInternalPadding(self: @This()) bool {
        return self.internal_padding_bytes != 0;
    }

    pub fn hasTrailingPadding(self: @This()) bool {
        return self.trailing_padding_bytes != 0;
    }
};

fn structInfo(comptime T: type) std.builtin.Type.Struct {
    return switch (@typeInfo(T)) {
        .@"struct" => |info| info,
        else => @compileError(std.fmt.comptimePrint(
            "reflections expects a struct type, got {s}",
            .{@typeName(T)},
        )),
    };
}

fn ensureByteAddressableStruct(comptime T: type) void {
    const info = structInfo(T);
    switch (info.layout) {
        .auto, .@"extern" => {},
        .@"packed" => @compileError(std.fmt.comptimePrint(
            "byte layout helpers do not support packed struct {s}; use packed layout/bit-oriented checks instead",
            .{@typeName(T)},
        )),
    }
}

pub fn runtimeStoredFieldCount(comptime T: type) usize {
    const info = structInfo(T);
    var count: usize = 0;
    inline for (info.fields) |field| {
        if (!field.is_comptime) count += 1;
    }
    return count;
}

pub fn fieldByteLayouts(comptime T: type) [runtimeStoredFieldCount(T)]FieldByteLayout {
    ensureByteAddressableStruct(T);

    const info = structInfo(T);
    var layouts: [runtimeStoredFieldCount(T)]FieldByteLayout = undefined;
    var next_index: usize = 0;

    inline for (info.fields, 0..) |field, source_index| {
        if (field.is_comptime) continue;

        const offset = @as(usize, @intCast(@offsetOf(T, field.name)));
        const size = @sizeOf(field.type);
        layouts[next_index] = .{
            .name = field.name,
            .source_index = source_index,
            .offset = offset,
            .size = size,
            .end = offset + size,
            .alignment = @alignOf(field.type),
            .is_comptime = field.is_comptime,
        };
        next_index += 1;
    }

    // Sort by actual byte offset, not source order.
    var i: usize = 1;
    while (i < layouts.len) : (i += 1) {
        const key = layouts[i];
        var j = i;
        while (j > 0) {
            const prev = layouts[j - 1];
            const should_swap = prev.offset > key.offset or
                (prev.offset == key.offset and prev.end > key.end);
            if (!should_swap) break;
            layouts[j] = prev;
            j -= 1;
        }
        layouts[j] = key;
    }

    return layouts;
}

pub fn byteLayoutStats(comptime T: type) ByteLayoutStats {
    ensureByteAddressableStruct(T);

    const layouts = fieldByteLayouts(T);
    var field_bytes: usize = 0;
    var internal_padding_bytes: usize = 0;
    var cursor: usize = 0;

    inline for (layouts) |layout| {
        field_bytes += layout.size;
        if (layout.offset > cursor) {
            internal_padding_bytes += layout.offset - cursor;
        }
        if (layout.end > cursor) {
            cursor = layout.end;
        }
    }

    const size = @sizeOf(T);
    const trailing_padding_bytes = size - cursor;

    return .{
        .size = size,
        .alignment = @alignOf(T),
        .field_count = layouts.len,
        .field_bytes = field_bytes,
        .internal_padding_bytes = internal_padding_bytes,
        .trailing_padding_bytes = trailing_padding_bytes,
        .total_padding_bytes = internal_padding_bytes + trailing_padding_bytes,
    };
}

pub fn hasWastedBytePadding(comptime T: type) bool {
    return byteLayoutStats(T).hasPadding();
}

pub fn hasInternalBytePadding(comptime T: type) bool {
    return byteLayoutStats(T).hasInternalPadding();
}

pub fn hasTrailingBytePadding(comptime T: type) bool {
    return byteLayoutStats(T).hasTrailingPadding();
}

pub fn fieldHasRuntimeStorage(comptime T: type, comptime field_name: []const u8) bool {
    const info = structInfo(T);
    inline for (info.fields) |field| {
        if (std.mem.eql(u8, field.name, field_name)) {
            return !field.is_comptime;
        }
    }
    @compileError(std.fmt.comptimePrint(
        "type {s} has no field named {s}",
        .{ @typeName(T), field_name },
    ));
}

pub fn fieldOffset(comptime T: type, comptime field_name: []const u8) usize {
    ensureByteAddressableStruct(T);
    if (!fieldHasRuntimeStorage(T, field_name)) {
        @compileError(std.fmt.comptimePrint(
            "field {s}.{s} is comptime-only and has no runtime byte offset",
            .{ @typeName(T), field_name },
        ));
    }
    return @as(usize, @intCast(@offsetOf(T, field_name)));
}

pub fn layoutReport(comptime T: type) []const u8 {
    ensureByteAddressableStruct(T);

    const info = structInfo(T);
    const stats = byteLayoutStats(T);
    const layouts = fieldByteLayouts(T);

    comptime var out: []const u8 = "";
    out = out ++ std.fmt.comptimePrint(
        "type {s}\nlayout={s} size={d} align={d} fields={d} field_bytes={d} padding={d} (internal={d}, trailing={d})\n",
        .{
            @typeName(T),
            @tagName(info.layout),
            stats.size,
            stats.alignment,
            stats.field_count,
            stats.field_bytes,
            stats.total_padding_bytes,
            stats.internal_padding_bytes,
            stats.trailing_padding_bytes,
        },
    );
    out = out ++ "memory map:\n";

    comptime var cursor: usize = 0;
    inline for (layouts) |layout| {
        if (layout.offset > cursor) {
            out = out ++ std.fmt.comptimePrint(
                "  padding [{d}..{d}) size={d}\n",
                .{ cursor, layout.offset, layout.offset - cursor },
            );
        }

        out = out ++ std.fmt.comptimePrint(
            "  field  [{d}..{d}) {s}: {s} size={d} align={d} source_index={d}\n",
            .{
                layout.offset,
                layout.end,
                layout.name,
                @typeName(@FieldType(T, layout.name)),
                layout.size,
                layout.alignment,
                layout.source_index,
            },
        );

        if (layout.end > cursor) cursor = layout.end;
    }

    if (stats.size > cursor) {
        out = out ++ std.fmt.comptimePrint(
            "  trailing padding [{d}..{d}) size={d}\n",
            .{ cursor, stats.size, stats.size - cursor },
        );
    }

    return out;
}

pub fn assertNoWastedBytePadding(comptime T: type) void {
    const stats = byteLayoutStats(T);
    if (stats.total_padding_bytes != 0) {
        @compileError(std.fmt.comptimePrint(
            "{s}\n\nassertNoWastedBytePadding failed:\n{s}",
            .{
                std.fmt.comptimePrint(
                    "{s} has {d} byte(s) of padding ({d} internal, {d} trailing)",
                    .{
                        @typeName(T),
                        stats.total_padding_bytes,
                        stats.internal_padding_bytes,
                        stats.trailing_padding_bytes,
                    },
                ),
                layoutReport(T),
            },
        ));
    }
}

pub fn assertNoInternalBytePadding(comptime T: type) void {
    const stats = byteLayoutStats(T);
    if (stats.internal_padding_bytes != 0) {
        @compileError(std.fmt.comptimePrint(
            "{s}\n\nassertNoInternalBytePadding failed:\n{s}",
            .{
                std.fmt.comptimePrint(
                    "{s} has {d} byte(s) of internal padding",
                    .{ @typeName(T), stats.internal_padding_bytes },
                ),
                layoutReport(T),
            },
        ));
    }
}

pub fn assertNoTrailingBytePadding(comptime T: type) void {
    const stats = byteLayoutStats(T);
    if (stats.trailing_padding_bytes != 0) {
        @compileError(std.fmt.comptimePrint(
            "{s}\n\nassertNoTrailingBytePadding failed:\n{s}",
            .{
                std.fmt.comptimePrint(
                    "{s} has {d} byte(s) of trailing padding",
                    .{ @typeName(T), stats.trailing_padding_bytes },
                ),
                layoutReport(T),
            },
        ));
    }
}

pub fn assertFieldFitsAlignment(comptime T: type, comptime field_name: []const u8) void {
    ensureByteAddressableStruct(T);

    const info = structInfo(T);
    inline for (info.fields) |field| {
        if (std.mem.eql(u8, field.name, field_name)) {
            if (field.is_comptime) {
                @compileError(std.fmt.comptimePrint(
                    "field {s}.{s} is comptime-only and has no runtime byte layout",
                    .{ @typeName(T), field_name },
                ));
            }

            const offset = @as(usize, @intCast(@offsetOf(T, field_name)));
            const alignment = @alignOf(field.type);
            if (offset % alignment != 0) {
                @compileError(std.fmt.comptimePrint(
                    "field {s}.{s} starts at byte offset {d}, which is not aligned to {d}\n\n{s}",
                    .{ @typeName(T), field_name, offset, alignment, layoutReport(T) },
                ));
            }
            return;
        }
    }

    @compileError(std.fmt.comptimePrint(
        "type {s} has no field named {s}",
        .{ @typeName(T), field_name },
    ));
}

pub fn assertHasField(comptime T: type, comptime field_name: []const u8) void {
    if (!@hasField(T, field_name)) {
        @compileError(std.fmt.comptimePrint(
            "type {s} is missing required field {s}",
            .{ @typeName(T), field_name },
        ));
    }
}

pub fn assertHasDecl(comptime T: type, comptime decl_name: []const u8) void {
    if (!@hasDecl(T, decl_name)) {
        @compileError(std.fmt.comptimePrint(
            "type {s} is missing required declaration {s}",
            .{ @typeName(T), decl_name },
        ));
    }
}

pub fn assertFieldType(comptime T: type, comptime field_name: []const u8, comptime Expected: type) void {
    assertHasField(T, field_name);
    const Actual = @FieldType(T, field_name);
    if (Actual != Expected) {
        @compileError(std.fmt.comptimePrint(
            "field {s}.{s} has type {s}, expected {s}",
            .{ @typeName(T), field_name, @typeName(Actual), @typeName(Expected) },
        ));
    }
}

pub fn assertSize(comptime T: type, comptime expected_size: usize) void {
    if (@sizeOf(T) != expected_size) {
        @compileError(std.fmt.comptimePrint(
            "type {s} has size {d}, expected {d}\n\n{s}",
            .{ @typeName(T), @sizeOf(T), expected_size, layoutReport(T) },
        ));
    }
}

pub fn assertAlignment(comptime T: type, comptime expected_alignment: usize) void {
    if (@alignOf(T) != expected_alignment) {
        @compileError(std.fmt.comptimePrint(
            "type {s} has alignment {d}, expected {d}\n\n{s}",
            .{ @typeName(T), @alignOf(T), expected_alignment, layoutReport(T) },
        ));
    }
}

pub fn assertFieldOffset(comptime T: type, comptime field_name: []const u8, comptime expected_offset: usize) void {
    const actual = fieldOffset(T, field_name);
    if (actual != expected_offset) {
        @compileError(std.fmt.comptimePrint(
            "field {s}.{s} has offset {d}, expected {d}\n\n{s}",
            .{ @typeName(T), field_name, actual, expected_offset, layoutReport(T) },
        ));
    }
}

pub fn assertFitsCacheLine(comptime T: type, comptime cache_line_bytes: usize) void {
    if (@sizeOf(T) > cache_line_bytes) {
        @compileError(std.fmt.comptimePrint(
            "type {s} is {d} bytes and does not fit in a {d}-byte cache line\n\n{s}",
            .{ @typeName(T), @sizeOf(T), cache_line_bytes, layoutReport(T) },
        ));
    }
}

test "byte layout stats and layout report" {
    const PackedEnough = struct {
        a: u32,
        b: u32,
    };

    const NeedsPadding = struct {
        a: u8,
        b: u32,
    };

    comptime {
        const okay = byteLayoutStats(PackedEnough);
        try std.testing.expect(okay.total_padding_bytes == 0);
        try std.testing.expect(okay.field_bytes == @sizeOf(PackedEnough));
        assertNoWastedBytePadding(PackedEnough);

        const padded = byteLayoutStats(NeedsPadding);
        try std.testing.expect(padded.total_padding_bytes != 0);
        try std.testing.expect(hasWastedBytePadding(NeedsPadding));
        try std.testing.expect(hasInternalBytePadding(NeedsPadding));

        const report = layoutReport(NeedsPadding);
        try std.testing.expect(report.len != 0);
    }
}

