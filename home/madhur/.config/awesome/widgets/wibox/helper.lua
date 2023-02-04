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