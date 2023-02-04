local awful = require("awful")
local beautiful = require("beautiful")

-- No border for maximized clients
local border_rules = {}
function border_rules.border_adjust(c)
    if awful.rules.match(c, {class = "Guake"}) then -- no borders if only 1 client visible
        c.border_width = 0
        return
    elseif c.maximized then
        c.border_color = "#ffaa00"
        c.border_width = 1
        return
    elseif #awful.screen.focused().clients > 1 then
        c.border_width = beautiful.border_width
        c.border_color = beautiful.border_focus
    end

    local t = awful.screen.focused().selected_tag
    if #t:clients() == 1 then
        c.border_width = 0
        -- firefox fix for fullscreen
        c:raise()
    else
        for _, c in ipairs(t:clients()) do
            c.border_width = 1
        end
    end
end

return border_rules