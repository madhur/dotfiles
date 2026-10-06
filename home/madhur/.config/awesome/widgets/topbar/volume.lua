local awful = require("awful")
local naughty = require("naughty")
local aw_volume_widget = require('awesome-wm-widgets.pactl-widget.volume')
local lain = require("lain")
local beautiful = require("beautiful")
local markup  = require("lain.util").markup
local wibox = require("wibox")

-- local volume = lain.widget.pulse({
--     settings = function()
--         local speaker_icon = "  "
--         local headphone_icon = " "
--         local icon
--         if tonumber(volume_now.index) == 2 then
--             icon = headphone_icon
--         else
--             icon = speaker_icon
--         end
--         widget:set_markup(markup.font(beautiful.font, icon .. volume_now.left))
--     end
-- })
-- awful.util.volume = volume


-- -- local volume_bar = lain.widget.pulsebar()
-- -- local volume_bar_widget = volume_bar.bar

-- local volume_widget = wibox.widget {
--     volume,
--     -- volume_bar_widget,
--     layout = wibox.layout.align.horizontal
-- }

-- volume_widget:buttons(awful.util.table.join(awful.button({}, 1, function()
--     -- left click
--     awful.spawn("pavucontrol")
-- end), awful.button({}, 2, function()
--     -- middle click
--     os.execute(string.format("pactl set-sink-volume %d 100%%", volume_bar.device))
--     -- volume_bar.update()
--     volume.update()
-- end), awful.button({}, 3, function()
--     -- right click
--     os.execute(string.format("pactl set-sink-mute %d toggle", volume_bar.device))
--     -- volume_bar.update()
--     volume.update()
-- end), awful.button({}, 4, function()
--     -- scroll up
--     os.execute(string.format("pactl set-sink-volume %d +1%%", volume_bar.device))
--     -- volume_bar.update()
--     volume.update()
-- end), awful.button({}, 5, function()
--     -- scroll down
--     os.execute(string.format("pactl set-sink-volume %d -1%%", volume_bar.device))
--     volume_bar.update()
--     volume.update()
-- end)))

awful.util.volume_new = aw_volume_widget
local pactl_widget = aw_volume_widget {
    widget_type = 'icon_and_text'
}

return pactl_widget