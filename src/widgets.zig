const abi = @import("abi.zig");
const themes = @import("themes.zig");
const draw = @import("draw.zig");

pub fn panel(
    frame: *abi.Frame,
    r: draw.Rect,
    theme: themes.Theme,
    hovered: bool,
    active: bool,
) void {
    const fill = if (active)
        theme.panel_bg_active
    else if (hovered)
        theme.panel_bg_hover
    else
        theme.panel_bg;

    const border = if (active)
        theme.accent_active
    else if (hovered)
        theme.accent_hover
    else
        theme.panel_border;

    draw.panel(frame, r, fill, border);
}

pub fn panelWithHeader(
    frame: *abi.Frame,
    r: draw.Rect,
    theme: themes.Theme,
    hovered: bool,
    active: bool,
    header_height: f32,
) void {
    panel(frame, r, theme, hovered, active);

    const header_color = if (active)
        theme.accent_active
    else if (hovered)
        theme.accent_hover
    else
        theme.accent;

    draw.fillRect(frame, .{
        .x = r.x,
        .y = r.top() - header_height,
        .w = r.w,
        .h = header_height,
    }, header_color);
}

