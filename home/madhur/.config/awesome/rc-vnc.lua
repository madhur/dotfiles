-- Minimal awesome config for VNC sessions (no autostart apps)

-- Prevent this instance from claiming the D-Bus notification name,
-- so notify-send goes to the real display's awesome instead.
package.loaded["naughty.dbus"] = { config = {}, get_clients = function() return {} end }

local awful = require("awful")
require("awful.autofocus")
local beautiful = require("beautiful")

beautiful.init(awful.util.get_themes_dir() .. "default/theme.lua")

awful.layout.layouts = { awful.layout.suit.tile, awful.layout.suit.floating }

awful.screen.connect_for_each_screen(function(s)
    awful.tag({ "1", "2", "3" }, s, awful.layout.layouts[1])
end)
