local net_speed_widget = require("awesome-wm-widgets.net-speed-widget.net-speed")
local awful = require("awful")
local naughty = require("naughty")

local net_widget = net_speed_widget()
net_widget:buttons(awful.util.table.join(awful.button({}, 1, function()
    -- left click
    awful.spawn.easy_async_with_shell(
        "ip -f inet addr show enp5s0 |grep inet | awk NF | sed -En -e 's/.*inet ([0-9.]+).*/\\1/p'",
        function(stdout, stderr, reason, exit_code)
            naughty.notify {
                text = tostring(stdout)
            }
        end)
end), awful.button({}, 3, function()
    -- right click
    awful.spawn.easy_async_with_shell("sudo netstat -ntpe | grep -v '127.0.0.1' | grep 'ESTABLISHED'",
        function(stdout, stderr, reason, exit_code)
            naughty.notify {
                text = tostring(stdout)
            }
        end)
end), awful.button({}, 2, function()
    -- middle click
    awful.spawn.easy_async_with_shell("conky -c ~/.config/conky/io.conf", function(stdout, stderr, reason, exit_code)
        naughty.notify {
            text = tostring(stdout)
        }
    end)
end)))

return net_widget