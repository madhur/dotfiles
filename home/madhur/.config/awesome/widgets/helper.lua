local wibox = require("wibox")
local lain = require("lain")

local function arrow(reverse)
    local font = "JetBrains Mono Nerd Font 13"
    local dark = theme.dark
    local darker = theme.darker
    local markup = nil
    if reverse then
        -- first arg is fg color, second is bg color
        markup = lain.util.markup.fontcolor(font, theme.dark, theme.darker, "")
    else
        markup = lain.util.markup.fontcolor(font, theme.darker, theme.dark, "")
    end

    local arrow =
        wibox.widget {
        markup = markup,
        widget = wibox.widget.textbox
    }
    -- return wibox.container.margin(arrow, 5, 5, 5, 5)
    return arrow
end


-- simple vertical separator widget
local spr = wibox.widget {
    markup = "<span font='JetBrains Mono Nerd Font 12'>|</span>",
    widget = wibox.widget.textbox
}

-- A transparent separataor widget with width of 10 pixels
local hr_spr = wibox.widget {
    color = "#000000",
    thickness = 2,
    forced_width = 10,
    orientation = "vertical",
    widget = wibox.widget.separator
}

local separator = wibox.widget.textbox(" ")
local separator2 = wibox.widget.textbox("  ")

local function powerline_rl(cr, width, height)
    local arrow_depth, offset = height / 2, 0

    -- Avoid going out of the (potential) clip area
    if arrow_depth < 0 then
        width = width + 2 * arrow_depth
        offset = -arrow_depth
    end

    cr:move_to(offset + arrow_depth, 0)
    cr:line_to(offset + width, 0)
    cr:line_to(offset + width - arrow_depth, height / 2)
    cr:line_to(offset + width, height)
    cr:line_to(offset + arrow_depth, height)
    cr:line_to(offset, height / 2)
    -- cr:set_source_rgb (0.5, 0, 0)
    cr:close_path()
    -- cr:stroke()
end

return {
    spr= spr,
    hr_spr = hr_spr,
    separator = separator,
    separator2 = separator2
}