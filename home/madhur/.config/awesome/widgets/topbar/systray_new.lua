--Standard Modules
local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local beautiful = require("beautiful")
local color = require("popups.color")
local dpi = beautiful.xresources.apply_dpi

--Separator
local separator = wibox.widget.textbox("   ")
local separator2 = wibox.widget.textbox("    ")

local systray = wibox.widget.systray()
systray:set_base_size(dpi(24))

--Tray toggle widget
local widget = wibox.widget {
  id = "icon",
  widget = wibox.widget.textbox,
  --image = os.getenv("HOME") .. "/.config/awesome/layout/topbar/icons/arrow-right.png",
  --resize = true,
  --opacity = 1,
  text = "  ",
  font = beautiful.font
}


--Main Widget
local top_left = wibox.widget {
      systray,
      widget,
      layout = wibox.layout.fixed.horizontal,
}

--Toggle function for systray
  widget:connect_signal("button::press", function(_, _, _, button)
  if button == 1 then
    systray.visible = not systray.visible
    if systray.visible then
      widget.text = "  "
    else
      widget.text = "  "
    end
  end
end)

return top_left
