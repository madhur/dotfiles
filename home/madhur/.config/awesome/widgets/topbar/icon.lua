local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")

local awesome_icon = wibox.widget {
    image = beautiful.awesome_icon,
    resize = false,
    widget = wibox.widget.imagebox
}

awesome_icon:connect_signal("button::press", function(_, _, _, button)
    if button == 1 then
        awful.spawn("jgmenu", false)
    end
end)

return awesome_icon