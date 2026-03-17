const std = @import("std");
const abi = @import("abi.zig");
const draw = @import("draw.zig");

pub const Options = struct {
    scale: f32 = 2.0,
    glyph_spacing: f32 = 1.0,
    line_spacing: f32 = 1.0,
};

pub const Size = struct {
    width: f32,
    height: f32,
};

const glyph_cols: f32 = 5;
const glyph_rows: f32 = 7;

pub fn measure(text: []const u8, options: Options) Size {
    const glyph_w = glyph_cols * options.scale;
    const glyph_h = glyph_rows * options.scale;
    const advance_x = glyph_w + options.glyph_spacing * options.scale;
    const advance_y = glyph_h + options.line_spacing * options.scale;
    _ = advance_y;

    var max_width: f32 = 0;
    var line_width: f32 = 0;
    var lines: u32 = 1;

    for (text) |c| {
        if (c == '\n') {
            if (line_width > 0) line_width -= options.glyph_spacing * options.scale;
            max_width = @max(max_width, line_width);
            line_width = 0;
            lines += 1;
            continue;
        }
        line_width += advance_x;
    }

    if (line_width > 0) line_width -= options.glyph_spacing * options.scale;
    max_width = @max(max_width, line_width);

    return .{
        .width = max_width / 2.0,
        .height = @as(f32, @floatFromInt(lines)) * glyph_h + @as(f32, @floatFromInt(lines - 1)) * options.line_spacing * options.scale,
    };
}

pub fn glyphWidth(options: Options) f32 {
    return glyph_cols * options.scale;
}

pub fn glyphHeight(options: Options) f32 {
    return glyph_rows * options.scale;
}

pub fn lineAdvance(options: Options) f32 {
    return glyphHeight(options) + options.line_spacing * options.scale;
}

pub fn drawText(frame: *abi.Frame, x: f32, y: f32, text: []const u8, options: Options, color: u32) void {
    const glyph_w = glyph_cols * options.scale;
    const glyph_h = glyph_rows * options.scale;
    const advance_x = glyph_w + options.glyph_spacing * options.scale;
    const advance_y = glyph_h + options.line_spacing * options.scale;

    var pen_x = x;
    var pen_y = y;

    for (text) |c| {
        if (c == '\n') {
            pen_x = x;
            pen_y -= advance_y;
            continue;
        }

        drawGlyph(frame, pen_x, pen_y, c, options.scale, color);
        pen_x += advance_x;
    }
}

pub fn drawTopLeft(frame: *abi.Frame, x: f32, y_top: f32, text: []const u8, options: Options, color: u32) void {
    const start_y = y_top - glyph_rows * options.scale;
    drawText(frame, x, start_y, text, options, color);
}

fn drawGlyph(frame: *abi.Frame, x: f32, y: f32, c: u8, scale: f32, color: u32) void {
    const rows = glyphFor(c);

    for (rows, 0..) |row_bits, row_index| {
        const row_y = y + @as(f32, @floatFromInt(6 - row_index)) * scale;
        var col: usize = 0;
        while (col < 5) {
            const mask: u8 = @as(u8, 1) << @as(u3, @intCast(4 - col));
            if ((row_bits & mask) == 0) {
                col += 1;
                continue;
            }

            const run_start = col;
            col += 1;
            while (col < 5) {
                const next_mask: u8 = @as(u8, 1) << @as(u3, @intCast(4 - col));
                if ((row_bits & next_mask) == 0) break;
                col += 1;
            }

            draw.fillRect(frame, .{
                .x = x + @as(f32, @floatFromInt(run_start)) * scale,
                .y = row_y,
                .w = @as(f32, @floatFromInt(col - run_start)) * scale,
                .h = scale,
            }, color);
        }
    }
}

fn glyphFor(c_in: u8) [7]u8 {
    const c = if (c_in >= 'a' and c_in <= 'z') c_in - 32 else c_in;

    return switch (c) {
        'A' => .{ 0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001 },
        'B' => .{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110 },
        'C' => .{ 0b01111, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b01111 },
        'D' => .{ 0b11110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b11110 },
        'E' => .{ 0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111 },
        'F' => .{ 0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000 },
        'G' => .{ 0b01110, 0b10001, 0b10000, 0b10111, 0b10001, 0b10001, 0b01110 },
        'H' => .{ 0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001 },
        'I' => .{ 0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b11111 },
        'J' => .{ 0b00001, 0b00001, 0b00001, 0b00001, 0b10001, 0b10001, 0b01110 },
        'K' => .{ 0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001 },
        'L' => .{ 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111 },
        'M' => .{ 0b10001, 0b11011, 0b10101, 0b10101, 0b10001, 0b10001, 0b10001 },
        'N' => .{ 0b10001, 0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001 },
        'O' => .{ 0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110 },
        'P' => .{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000 },
        'Q' => .{ 0b01110, 0b10001, 0b10001, 0b10001, 0b10101, 0b10010, 0b01101 },
        'R' => .{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001 },
        'S' => .{ 0b01111, 0b10000, 0b10000, 0b01110, 0b00001, 0b00001, 0b11110 },
        'T' => .{ 0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100 },
        'U' => .{ 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110 },
        'V' => .{ 0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b01010, 0b00100 },
        'W' => .{ 0b10001, 0b10001, 0b10001, 0b10101, 0b10101, 0b10101, 0b01010 },
        'X' => .{ 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b01010, 0b10001 },
        'Y' => .{ 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100 },
        'Z' => .{ 0b11111, 0b00010, 0b00100, 0b00100, 0b01000, 0b10000, 0b11111 },

        '0' => .{ 0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110 },
        '1' => .{ 0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110 },
        '2' => .{ 0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0b01000, 0b11111 },
        '3' => .{ 0b11110, 0b00001, 0b00001, 0b01110, 0b00001, 0b00001, 0b11110 },
        '4' => .{ 0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010 },
        '5' => .{ 0b11111, 0b10000, 0b10000, 0b11110, 0b00001, 0b00001, 0b11110 },
        '6' => .{ 0b01110, 0b10000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110 },
        '7' => .{ 0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000 },
        '8' => .{ 0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110 },
        '9' => .{ 0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00001, 0b01110 },

        ' ' => .{ 0, 0, 0, 0, 0, 0, 0 },
        '.' => .{ 0, 0, 0, 0, 0, 0b01100, 0b01100 },
        ',' => .{ 0, 0, 0, 0, 0, 0b00100, 0b01000 },
        ':' => .{ 0, 0b01100, 0b01100, 0, 0b01100, 0b01100, 0 },
        ';' => .{ 0, 0b01100, 0b01100, 0, 0b01100, 0b00100, 0b01000 },
        '-' => .{ 0, 0, 0, 0b11111, 0, 0, 0 },
        '_' => .{ 0, 0, 0, 0, 0, 0, 0b11111 },
        '/' => .{ 0b00001, 0b00010, 0b00100, 0b00100, 0b01000, 0b10000, 0b00000 },
        '(' => .{ 0b00010, 0b00100, 0b01000, 0b01000, 0b01000, 0b00100, 0b00010 },
        ')' => .{ 0b01000, 0b00100, 0b00010, 0b00010, 0b00010, 0b00100, 0b01000 },
        '[' => .{ 0b01110, 0b01000, 0b01000, 0b01000, 0b01000, 0b01000, 0b01110 },
        ']' => .{ 0b01110, 0b00010, 0b00010, 0b00010, 0b00010, 0b00010, 0b01110 },
        '+' => .{ 0, 0b00100, 0b00100, 0b11111, 0b00100, 0b00100, 0 },
        '=' => .{ 0, 0b11111, 0, 0b11111, 0, 0, 0 },
        '!' => .{ 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0, 0b00100 },
        '?' => .{ 0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0, 0b00100 },
        '\'' => .{ 0b00100, 0b00100, 0b01000, 0, 0, 0, 0 },
        '"' => .{ 0b01010, 0b01010, 0b00100, 0, 0, 0, 0 },
        '#' => .{ 0b01010, 0b11111, 0b01010, 0b01010, 0b11111, 0b01010, 0 },
        '%' => .{ 0b11001, 0b11010, 0b00100, 0b01000, 0b10110, 0b00110, 0 },
        '*' => .{ 0, 0b10101, 0b01110, 0b11111, 0b01110, 0b10101, 0 },
        '<' => .{ 0b00010, 0b00100, 0b01000, 0b10000, 0b01000, 0b00100, 0b00010 },
        '>' => .{ 0b01000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b01000 },
        else => .{ 0b01110, 0b10001, 0b00010, 0b00100, 0b00000, 0b00100, 0b00000 },
    };
}

