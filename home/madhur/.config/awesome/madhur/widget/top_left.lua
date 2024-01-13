--Standard Modules
local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")
local wibox = require("wibox")
local color = require("madhur.widget.colors")
local dpi = beautiful.xresources.apply_dpi

local separator = wibox.widget.textbox("  ")
local separator2 = wibox.widget.textbox("  ")

local ss_tool = require("popups.screen_record.screenshot.main")

--Popup Menus
local control = require("popups.control_center.main")
local notif_center = require("popups.notif_center.main")
local media = require("popups.media_player.main")
local notification = require("widgets.topbar.notification")

-- --Battery Widget
-- local batteryarc_widget = require("deco.batteryarc")


--Screenshot button
local screenshot = wibox.widget {
      widget = wibox.widget.textbox,
      --image = os.getenv("HOME") .. "/.config/awesome/layout/topbar/icons/screenshot.png",
      text = " 󰹑 ",
      font = beautiful.font,
  }

screenshot:connect_signal("button::press", function(_, _, _, button)
  if button == 1 then
    -- awful.spawn.with_shell(
    --   'scrot /tmp/screenshot.png && convert /tmp/screenshot.png -resize 20% /tmp/resized_screenshot.png && dunstify -i /tmp/resized_screenshot.png "Screenshot Captured" && cp /tmp/screenshot.png ~/Pictures/file1_`date +"%Y%m%d_%H%M%S"`.png && rm /tmp/resized_screenshot.png && rm /tmp/screenshot.png'
    -- )
    ss_tool.visible = not ss_tool.visible
  elseif button == 3 then
    awful.spawn.with_shell(
      'scrot /tmp/screenshot.png && convert /tmp/screenshot.png -resize 20% /tmp/resized_screenshot.png && dunstify -i /tmp/resized_screenshot.png "Screenshot Captured" && cp /tmp/screenshot.png ~/Pictures/file1_`date +"%Y%m%d_%H%M%S"`.png && rm /tmp/resized_screenshot.png && rm /tmp/screenshot.png'
    )
  end
end)


local settings = wibox.widget {
      widget = wibox.widget.textbox,
      text = "  ",
      font = beautiful.font,
}

settings:connect_signal("button::release", function()
  control.visible = not control.visible
  notif_center.visible = false
  media.visible = false
end)


local music = wibox.widget {
      widget = wibox.widget.textbox,
      text = "  ",
      font = beautiful.font,
  }

music:connect_signal("button::release", function()
  media.visible = not media.visible
  control.visible = false
end)



--Main Window
local system_tray = wibox.widget {
   --   music,
   --   separator,
      settings,
      separator,
   notification,
   --   screenshot,

      layout = wibox.layout.fixed.horizontal,
 

}

-- return system_tray
return notification
