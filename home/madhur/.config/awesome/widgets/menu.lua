local awesome = awesome
local awful = require("awful")
local beautiful = require("beautiful")
local config = require("config")
local hotkeys_popup = require("awful.hotkeys_popup").widget
-- {{{ Menu
-- Create a launcher widget and a main menu
local myawesomemenu = {
    {
        "hotkeys",
        function()
            hotkeys_popup.show_help(nil, awful.screen.focused())
        end
    },
    {"manual", config.terminal .. " -e man awesome"},
    {"restart", awesome.restart},
    {
        "quit",
        function()
            awesome.quit()
        end
    }
}

local mymainmenu =
    awful.menu(
    {
        items = {
            {"awesome", myawesomemenu, beautiful.awesome_icon},
            {"open terminal", config.terminal}
        }
    }
)

return mymainmenu
