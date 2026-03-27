const std = @import("std");

pub const Id = u64;

pub fn id(label: []const u8) Id {
    return std.hash.Wyhash.hash(0, label);
}

pub const Size = struct {
    width: f32 = 0,
    height: f32 = 0,
};

pub const Rect = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,

    pub fn right(self: Rect) f32 {
        return self.x + self.width;
    }

    pub fn bottom(self: Rect) f32 {
        return self.y + self.height;
    }
};

pub const Padding = struct {
    left: f32 = 0,
    right: f32 = 0,
    top: f32 = 0,
    bottom: f32 = 0,

    pub fn all(v: f32) Padding {
        return .{ .left = v, .right = v, .top = v, .bottom = v };
    }

    pub fn horizontal(self: Padding) f32 {
        return self.left + self.right;
    }

    pub fn vertical(self: Padding) f32 {
        return self.top + self.bottom;
    }
};

pub const Direction = enum {
    left_to_right,
    top_to_bottom,
};

pub const AlignX = enum {
    left,
    center,
    right,
};

pub const AlignY = enum {
    top,
    center,
    bottom,
};

pub const ChildAlignment = struct {
    x: AlignX = .left,
    y: AlignY = .top,
};

pub const MinMax = struct {
    min: f32 = 0,
    max: f32 = std.math.inf(f32),

    pub fn clamp(self: MinMax, value: f32) f32 {
        return std.math.clamp(value, self.min, self.max);
    }
};

pub const AxisSizing = union(enum) {
    fit: MinMax,
    grow: MinMax,
    fixed: f32,
    percent: f32,

    pub fn fitDefault() AxisSizing {
        return .{ .fit = .{} };
    }

    pub fn growDefault() AxisSizing {
        return .{ .grow = .{} };
    }

    pub fn fixedPx(v: f32) AxisSizing {
        return .{ .fixed = v };
    }

    pub fn percentOfParent(v: f32) AxisSizing {
        return .{ .percent = v };
    }

    pub fn minConstraint(self: AxisSizing, intrinsic: f32) f32 {
        return switch (self) {
            .fit => |mm| mm.clamp(intrinsic),
            .grow => |mm| mm.clamp(intrinsic),
            .fixed => |v| v,
            .percent => 0,
        };
    }

    pub fn preferred(self: AxisSizing, intrinsic: f32, available: f32) f32 {
        return switch (self) {
            .fit => |mm| mm.clamp(intrinsic),
            .grow => |mm| mm.clamp(intrinsic),
            .fixed => |v| v,
            .percent => |p| available * std.math.clamp(p, 0, 1),
        };
    }

    pub fn expanded(self: AxisSizing, available: f32) f32 {
        return switch (self) {
            .fit => |mm| mm.clamp(available),
            .grow => |mm| mm.clamp(available),
            .fixed => |v| v,
            .percent => |p| available * std.math.clamp(p, 0, 1),
        };
    }

    pub fn maxConstraint(self: AxisSizing) f32 {
        return switch (self) {
            .fit => |mm| mm.max,
            .grow => |mm| mm.max,
            .fixed => |v| v,
            .percent => std.math.inf(f32),
        };
    }

    pub fn canGrow(self: AxisSizing) bool {
        return switch (self) {
            .grow => true,
            else => false,
        };
    }

    pub fn canShrink(self: AxisSizing) bool {
        return switch (self) {
            .fit, .grow => true,
            else => false,
        };
    }
};

pub const Sizing = struct {
    width: AxisSizing = AxisSizing.fitDefault(),
    height: AxisSizing = AxisSizing.fitDefault(),
};

pub const Layout = struct {
    sizing: Sizing = .{},
    padding: Padding = .{},
    child_gap: f32 = 0,
    child_alignment: ChildAlignment = .{},
    direction: Direction = .left_to_right,
};

pub const Declaration = struct {
    id: ?Id = null,
    layout: Layout = .{},
    intrinsic_size: Size = .{},
    user_data: usize = 0,
};

const Node = struct {
    id: ?Id,
    layout: Layout,
    intrinsic_size: Size,
    fit_size: Size = .{},
    min_size: Size = .{},
    rect: Rect = .{},
    user_data: usize,
    parent: ?usize = null,
    first_child: ?usize = null,
    last_child: ?usize = null,
    next_sibling: ?usize = null,
};

pub const Context = struct {
    allocator: std.mem.Allocator,
    nodes: std.ArrayListUnmanaged(Node) = .{},
    stack: std.ArrayListUnmanaged(usize) = .{},

    pub fn init(allocator: std.mem.Allocator) Context {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Context) void {
        self.nodes.deinit(self.allocator);
        self.stack.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn begin(self: *Context, root_size: Size) !void {
        self.nodes.clearRetainingCapacity();
        self.stack.clearRetainingCapacity();

        try self.nodes.append(self.allocator, .{
            .id = id("__root__"),
            .layout = .{
                .sizing = .{
                    .width = .{ .fixed = root_size.width },
                    .height = .{ .fixed = root_size.height },
                },
                .direction = .top_to_bottom,
            },
            .intrinsic_size = root_size,
            .fit_size = root_size,
            .min_size = root_size,
            .rect = .{ .x = 0, .y = 0, .width = root_size.width, .height = root_size.height },
            .user_data = 0,
        });
        try self.stack.append(self.allocator, 0);
    }

    pub fn open(self: *Context, declaration: Declaration) !void {
        if (self.stack.items.len == 0) return error.LayoutNotBegun;

        const parent_index = self.stack.items[self.stack.items.len - 1];
        const index = self.nodes.items.len;
        try self.nodes.append(self.allocator, .{
            .id = declaration.id,
            .layout = declaration.layout,
            .intrinsic_size = declaration.intrinsic_size,
            .user_data = declaration.user_data,
            .parent = parent_index,
        });

        var parent = &self.nodes.items[parent_index];
        if (parent.first_child == null) {
            parent.first_child = index;
        } else {
            self.nodes.items[parent.last_child.?].next_sibling = index;
        }
        parent.last_child = index;

        try self.stack.append(self.allocator, index);
    }

    pub fn close(self: *Context) void {
        std.debug.assert(self.stack.items.len > 1);
        _ = self.stack.pop();
    }

    pub fn end(self: *Context) !void {
        if (self.stack.items.len != 1) return error.UnbalancedOpenClose;
        self.measureRecursive(0);
        try self.layoutRecursive(0, self.nodes.items[0].rect);
        _ = self.stack.pop();
    }

    pub fn rectOf(self: *const Context, query_id: Id) ?Rect {
        for (self.nodes.items) |node| {
            if (node.id != null and node.id.? == query_id) return node.rect;
        }
        return null;
    }

    pub fn nodeCount(self: *const Context) usize {
        return self.nodes.items.len;
    }

    fn measureRecursive(self: *Context, index: usize) void {
        var node = &self.nodes.items[index];

        var content_w = node.intrinsic_size.width;
        var content_h = node.intrinsic_size.height;

        if (node.first_child) |first_child| {
            var child = first_child;
            var count: usize = 0;
            var accum_main: f32 = 0;
            var accum_cross: f32 = 0;
            while (true) {
                self.measureRecursive(child);
                const c = self.nodes.items[child];
                if (node.layout.direction == .left_to_right) {
                    accum_main += c.fit_size.width;
                    accum_cross = @max(accum_cross, c.fit_size.height);
                } else {
                    accum_main += c.fit_size.height;
                    accum_cross = @max(accum_cross, c.fit_size.width);
                }
                count += 1;
                if (c.next_sibling) |next| child = next else break;
            }
            if (count > 1) accum_main += @as(f32, @floatFromInt(count - 1)) * node.layout.child_gap;
            if (node.layout.direction == .left_to_right) {
                content_w = @max(content_w, accum_main + node.layout.padding.horizontal());
                content_h = @max(content_h, accum_cross + node.layout.padding.vertical());
            } else {
                content_w = @max(content_w, accum_cross + node.layout.padding.horizontal());
                content_h = @max(content_h, accum_main + node.layout.padding.vertical());
            }
        }

        node.fit_size = .{
            .width = node.layout.sizing.width.preferred(content_w, 0),
            .height = node.layout.sizing.height.preferred(content_h, 0),
        };
        node.min_size = .{
            .width = node.layout.sizing.width.minConstraint(content_w),
            .height = node.layout.sizing.height.minConstraint(content_h),
        };
    }

    fn layoutRecursive(self: *Context, index: usize, rect: Rect) !void {
        self.nodes.items[index].rect = rect;
        const node = self.nodes.items[index];
        if (node.first_child == null) return;

        const inner_x = rect.x + node.layout.padding.left;
        const inner_y = rect.y + node.layout.padding.top;
        const inner_w = @max(rect.width - node.layout.padding.horizontal(), 0);
        const inner_h = @max(rect.height - node.layout.padding.vertical(), 0);

        var child_opt = node.first_child;
        var main_used: f32 = 0;
        var child_count: usize = 0;
        var grow_count: usize = 0;

        while (child_opt) |child_index| {
            const child = self.nodes.items[child_index];
            const child_size = self.initialChildSize(child, inner_w, inner_h, node.layout.direction);
            self.nodes.items[child_index].rect.width = child_size.width;
            self.nodes.items[child_index].rect.height = child_size.height;

            if (node.layout.direction == .left_to_right) {
                main_used += child_size.width;
                if (child.layout.sizing.width.canGrow()) grow_count += 1;
            } else {
                main_used += child_size.height;
                if (child.layout.sizing.height.canGrow()) grow_count += 1;
            }
            child_count += 1;
            child_opt = child.next_sibling;
        }

        if (child_count > 1) main_used += @as(f32, @floatFromInt(child_count - 1)) * node.layout.child_gap;
        const main_available = if (node.layout.direction == .left_to_right) inner_w else inner_h;
        const delta = main_available - main_used;

        if (delta > 0 and grow_count > 0) {
            self.distributeExtraFromChildren(node.first_child.?, node.layout.direction, delta);
        } else if (delta < 0) {
            self.distributeShrinkFromChildren(node.first_child.?, node.layout.direction, -delta);
        }

        var final_main_used: f32 = 0;
        child_opt = node.first_child;
        while (child_opt) |child_index| {
            const child = self.nodes.items[child_index];
            final_main_used += if (node.layout.direction == .left_to_right) child.rect.width else child.rect.height;
            child_opt = child.next_sibling;
            if (child_opt != null) final_main_used += node.layout.child_gap;
        }

        const main_offset = switch (node.layout.direction) {
            .left_to_right => alignOffsetX(node.layout.child_alignment.x, @max(main_available - final_main_used, 0)),
            .top_to_bottom => alignOffsetY(node.layout.child_alignment.y, @max(main_available - final_main_used, 0)),
        };

        var cursor_main = main_offset;
        child_opt = node.first_child;
        while (child_opt) |child_index| {
            const child = self.nodes.items[child_index];
            var child_rect = Rect{};
            if (node.layout.direction == .left_to_right) {
                const cross_leftover = @max(inner_h - child.rect.height, 0);
                const cross_offset = alignOffsetY(node.layout.child_alignment.y, cross_leftover);
                child_rect = .{
                    .x = inner_x + cursor_main,
                    .y = inner_y + cross_offset,
                    .width = child.rect.width,
                    .height = child.rect.height,
                };
                cursor_main += child.rect.width + node.layout.child_gap;
            } else {
                const cross_leftover = @max(inner_w - child.rect.width, 0);
                const cross_offset = alignOffsetX(node.layout.child_alignment.x, cross_leftover);
                child_rect = .{
                    .x = inner_x + cross_offset,
                    .y = inner_y + cursor_main,
                    .width = child.rect.width,
                    .height = child.rect.height,
                };
                cursor_main += child.rect.height + node.layout.child_gap;
            }
            const next = child.next_sibling;
            try self.layoutRecursive(child_index, child_rect);
            child_opt = next;
        }
    }

    fn initialChildSize(self: *Context, child: Node, inner_w: f32, inner_h: f32, direction: Direction) Size {
        _ = self;
        var result = child.fit_size;
        if (direction == .left_to_right) {
            result.width = child.layout.sizing.width.preferred(child.fit_size.width, inner_w);
            result.height = switch (child.layout.sizing.height) {
                .grow => child.layout.sizing.height.expanded(inner_h),
                else => child.layout.sizing.height.preferred(child.fit_size.height, inner_h),
            };
        } else {
            result.height = child.layout.sizing.height.preferred(child.fit_size.height, inner_h);
            result.width = switch (child.layout.sizing.width) {
                .grow => child.layout.sizing.width.expanded(inner_w),
                else => child.layout.sizing.width.preferred(child.fit_size.width, inner_w),
            };
        }
        return result;
    }

    fn distributeExtraFromChildren(self: *Context, first_child: usize, direction: Direction, extra: f32) void {
        var remaining = extra;
        while (remaining > 0.01) {
            var grow_count: usize = 0;
            var child_opt: ?usize = first_child;
            while (child_opt) |child_index| {
                const node = self.nodes.items[child_index];
                if ((direction == .left_to_right and node.layout.sizing.width.canGrow()) or
                    (direction == .top_to_bottom and node.layout.sizing.height.canGrow()))
                {
                    grow_count += 1;
                }
                child_opt = node.next_sibling;
            }
            if (grow_count == 0) break;
            const share = remaining / @as(f32, @floatFromInt(grow_count));
            var spent: f32 = 0;
            child_opt = first_child;
            while (child_opt) |child_index| {
                const node = self.nodes.items[child_index];
                if (direction == .left_to_right) {
                    if (node.layout.sizing.width.canGrow()) {
                        const max_v = node.layout.sizing.width.maxConstraint();
                        const next = @min(self.nodes.items[child_index].rect.width + share, max_v);
                        spent += next - self.nodes.items[child_index].rect.width;
                        self.nodes.items[child_index].rect.width = next;
                    }
                } else {
                    if (node.layout.sizing.height.canGrow()) {
                        const max_v = node.layout.sizing.height.maxConstraint();
                        const next = @min(self.nodes.items[child_index].rect.height + share, max_v);
                        spent += next - self.nodes.items[child_index].rect.height;
                        self.nodes.items[child_index].rect.height = next;
                    }
                }
                child_opt = node.next_sibling;
            }
            if (spent <= 0.01) break;
            remaining -= spent;
        }
    }

    fn distributeShrinkFromChildren(self: *Context, first_child: usize, direction: Direction, deficit: f32) void {
        var remaining = deficit;
        while (remaining > 0.01) {
            var shrink_count: usize = 0;
            var child_opt: ?usize = first_child;
            while (child_opt) |child_index| {
                const node = self.nodes.items[child_index];
                if (direction == .left_to_right) {
                    if (node.layout.sizing.width.canShrink() and self.nodes.items[child_index].rect.width > node.min_size.width + 0.01) {
                        shrink_count += 1;
                    }
                } else {
                    if (node.layout.sizing.height.canShrink() and self.nodes.items[child_index].rect.height > node.min_size.height + 0.01) {
                        shrink_count += 1;
                    }
                }
                child_opt = node.next_sibling;
            }
            if (shrink_count == 0) break;
            const share = remaining / @as(f32, @floatFromInt(shrink_count));
            var saved: f32 = 0;
            child_opt = first_child;
            while (child_opt) |child_index| {
                const node = self.nodes.items[child_index];
                if (direction == .left_to_right) {
                    if (node.layout.sizing.width.canShrink()) {
                        const next = @max(self.nodes.items[child_index].rect.width - share, node.min_size.width);
                        saved += self.nodes.items[child_index].rect.width - next;
                        self.nodes.items[child_index].rect.width = next;
                    }
                } else {
                    if (node.layout.sizing.height.canShrink()) {
                        const next = @max(self.nodes.items[child_index].rect.height - share, node.min_size.height);
                        saved += self.nodes.items[child_index].rect.height - next;
                        self.nodes.items[child_index].rect.height = next;
                    }
                }
                child_opt = node.next_sibling;
            }
            if (saved <= 0.01) break;
            remaining -= saved;
        }
    }
};

fn alignOffsetX(align_x: AlignX, leftover: f32) f32 {
    return switch (align_x) {
        .left => 0,
        .center => leftover / 2,
        .right => leftover,
    };
}

fn alignOffsetY(align_y: AlignY, leftover: f32) f32 {
    return switch (align_y) {
        .top => 0,
        .center => leftover / 2,
        .bottom => leftover,
    };
}

test "fixed sidebar and grow main" {
    var ctx = Context.init(std.testing.allocator);
    defer ctx.deinit();

    try ctx.begin(.{ .width = 1000, .height = 600 });
    try ctx.open(.{ .id = id("outer"), .layout = .{
        .sizing = .{
            .width = .{ .grow = .{} },
            .height = .{ .grow = .{} },
        },
        .padding = Padding.all(16),
        .child_gap = 16,
        .direction = .left_to_right,
    } });
    try ctx.open(.{ .id = id("sidebar"), .layout = .{
        .sizing = .{
            .width = .{ .fixed = 240 },
            .height = .{ .grow = .{} },
        },
    } });
    ctx.close();
    try ctx.open(.{ .id = id("main"), .layout = .{
        .sizing = .{
            .width = .{ .grow = .{} },
            .height = .{ .grow = .{} },
        },
    } });
    ctx.close();
    ctx.close();
    try ctx.end();

    const outer = ctx.rectOf(id("outer")).?;
    const sidebar = ctx.rectOf(id("sidebar")).?;
    const main = ctx.rectOf(id("main")).?;

    try std.testing.expectApproxEqAbs(@as(f32, 16), outer.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 16), sidebar.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 240), sidebar.width, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1000 - 16 - 16 - 240 - 16), main.width, 0.01);
}

