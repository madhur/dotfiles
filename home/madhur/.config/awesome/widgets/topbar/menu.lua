local wibox = require("wibox")
local awful = require("awful")

local jgmenu_right_click = wibox.widget {
    resize = true,
    widget = wibox.widget.imagebox,
    forced_width = 300
}

jgmenu_right_click:connect_signal("button::press", function(_, _, _, button)
    if button == 3 then
        awful.spawn("jgmenu", false)
    end
end)

return jgmenu_right_click