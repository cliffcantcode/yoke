const std = @import("std");

const reflection = @import("reflection.zig");

// Fastest path for day-to-day work: change this one line and save.
// Options: catppuccin_mocha, adventhealth_dark, adventhealth_light
pub const default = catppuccin_mocha;

pub const Theme = struct {
    name: []const u8,

    canvas_bg: u32,
    panel_bg: u32,
    panel_bg_hover: u32,
    panel_bg_active: u32,
    panel_border: u32,

    text: u32,
    text_muted: u32,

    accent: u32,
    accent_hover: u32,
    accent_active: u32,

    success: u32,
    warning: u32,
    danger: u32,

    cursor: u32,
    origin_marker: u32,

    _padding: [4]u8 = undefined,

    comptime {
        reflection.assertNoWastedBytePadding(@This());
    }
};

pub fn rgb(r: u8, g: u8, b: u8) u32 {
    return (@as(u32, r) << 16) | (@as(u32, g) << 8) | @as(u32, b);
}

pub fn hex(value: u24) u32 {
    return @as(u32, value);
}

pub const catppuccin_mocha = Theme{
    .name = "catppuccin_mocha",
    .canvas_bg = hex(0x11111b),
    .panel_bg = hex(0x1e1e2e),
    .panel_bg_hover = hex(0x313244),
    .panel_bg_active = hex(0x45475a),
    .panel_border = hex(0x585b70),
    .text = hex(0xcdd6f4),
    .text_muted = hex(0xa6adc8),
    .accent = hex(0x89b4fa),
    .accent_hover = hex(0x74c7ec),
    .accent_active = hex(0xcba6f7),
    .success = hex(0xa6e3a1),
    .warning = hex(0xf9e2af),
    .danger = hex(0xf38ba8),
    .cursor = hex(0xf5e0dc),
    .origin_marker = hex(0xf38ba8),
};

// Brand-inspired dark work theme:
// official AdventHealth brand colors drive the accents,
// while the neutral background colors are derived for a comfortable dark UI.
pub const adventhealth_dark = Theme{
    .name = "adventhealth_dark",
    .canvas_bg = hex(0x0c1418),
    .panel_bg = hex(0x102027),
    .panel_bg_hover = hex(0x15303a),
    .panel_bg_active = hex(0x1d3c49),
    .panel_border = hex(0x2f5560),
    .text = hex(0xe8e9e9),
    .text_muted = hex(0xa9b6bb),
    .accent = hex(0x006298),
    .accent_hover = hex(0x157ea8),
    .accent_active = hex(0x00a3e0),
    .success = hex(0x84bd00),
    .warning = hex(0xe5f5fc),
    .danger = hex(0xda291c),
    .cursor = hex(0xe5f5fc),
    .origin_marker = hex(0x84bd00),
};

pub const adventhealth_light = Theme{
    .name = "adventhealth_light",
    .canvas_bg = hex(0xf7fafb),
    .panel_bg = hex(0xffffff),
    .panel_bg_hover = hex(0xf4f9fb),
    .panel_bg_active = hex(0xe5f5fc), // official light blue
    .panel_border = hex(0xbfd6df),

    .text = hex(0x1c2c34),
    .text_muted = hex(0x666666), // official gray

    .accent = hex(0x006298), // official dark blue
    .accent_hover = hex(0x157ea8), // official blue
    .accent_active = hex(0x00a3e0), // official cyan

    .success = hex(0x84bd00), // official lime
    .warning = hex(0xf3df9b), // derived
    .danger = hex(0xda291c), // official red

    .cursor = hex(0x006298),
    .origin_marker = hex(0x84bd00),
};

pub fn byName(name: []const u8) ?Theme {
    if (std.mem.eql(u8, name, "catppuccin_mocha")) return catppuccin_mocha;
    if (std.mem.eql(u8, name, "adventhealth_dark")) return adventhealth_dark;
    if (std.mem.eql(u8, name, "adventhealth_light")) return adventhealth_light;
    return null;
}

