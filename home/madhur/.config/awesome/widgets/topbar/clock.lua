local awful = require("awful")
local calendar_widget = require("awesome-wm-widgets.calendar-widget.calendar")
local naughty = require("naughty")
local beautiful = require("beautiful")
local markup  = require("lain.util").markup

local clock = awful.widget.watch("date +'%a %d %b %R'", 60, function(widget, stdout)
    widget:set_markup(" " .. markup.font(beautiful.font, " " .. stdout))
end)

local cw = calendar_widget({
    theme = "nord",
    placement = "top_right",
    start_sunday = false,
    radius = 0
})

clock:buttons(awful.util.table.join(awful.button({}, 1, function()
    -- cw.toggle()
    awful.spawn.easy_async_with_shell("eww open calendar --toggle", function(stdout, stderr, reason, exit_code)

    end)

end), awful.button({}, 3, function()
    -- left click
    awful.spawn.easy_async_with_shell("date -u", function(stdout, stderr, reason, exit_code)
        naughty.notify {
            text = tostring(stdout)
        }
    end)
end)))

return clock