local awful = require("awful")
local wibox = require("wibox")

local empty = wibox.widget{
    text = "",
    widget = wibox.widget.textbox
}
local jgmenu = wibox.widget {
    layout  = wibox.layout.flex.horizontal,
    spacing = 100,
    empty,
    empty,
    empty,
  
}

jgmenu:connect_signal("button::press", function(_, _, _, button)
    if button == 3 then
        awful.spawn("jgmenu", false)
    end
end)

return jgmenu
