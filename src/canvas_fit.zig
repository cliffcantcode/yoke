const abi = @import("abi.zig");
const draw = @import("draw.zig");

pub const Transform = struct {
    scale: f32,
    dx: f32,
    dy: f32,
    dst: draw.Rect,
};

pub fn contain(src_w: f32, src_h: f32, dst: draw.Rect) Transform {
    if (src_w <= 0.0 or src_h <= 0.0 or dst.w <= 0.0 or dst.h <= 0.0) {
        return .{
            .scale = 0.0,
            .dx = dst.x,
            .dy = dst.y,
            .dst = draw.rect(dst.x, dst.y, 0.0, 0.0),
        };
    }

    const scale = @min(dst.w / src_w, dst.h / src_h);
    const fitted_w = src_w * scale;
    const fitted_h = src_h * scale;
    const dx = dst.x + @max((dst.w - fitted_w) * 0.5, 0.0);
    const dy = dst.y + @max((dst.h - fitted_h) * 0.5, 0.0);

    return .{
        .scale = scale,
        .dx = dx,
        .dy = dy,
        .dst = draw.rect(dx, dy, fitted_w, fitted_h),
    };
}

pub fn transformCommandSlice(commands: []abi.RenderCommand, tx: Transform) void {
    if (tx.scale <= 0.0) return;

    for (commands) |*cmd| {
        const kind: abi.RenderCommandKind = @enumFromInt(cmd.kind);
        switch (kind) {
            .clear => {
                cmd.kind = @intFromEnum(abi.RenderCommandKind.fill_rect);
                cmd.x0 = tx.dst.x;
                cmd.y0 = tx.dst.y;
                cmd.x1 = tx.dst.right();
                cmd.y1 = tx.dst.top();
            },
            .pop_clip => {},
            .fill_rect, .stroke_rect, .line, .push_clip => {
                cmd.x0 = tx.dx + cmd.x0 * tx.scale;
                cmd.y0 = tx.dy + cmd.y0 * tx.scale;
                cmd.x1 = tx.dx + cmd.x1 * tx.scale;
                cmd.y1 = tx.dy + cmd.y1 * tx.scale;

                switch (kind) {
                    .stroke_rect, .line => cmd.thickness *= tx.scale,
                    else => {},
                }
            },
        }
    }
}
