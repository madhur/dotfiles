local awesome, client, tag = awesome, client, tag
local tostring =  tostring
local awful = require("awful")
local gears = require("gears")
require("awful.autofocus")
local beautiful = require("beautiful")
local lain = require("lain")
local naughty = require("naughty")
naughty.config.defaults["icon_size"] = 100
local madhur = require("madhur")
local border_rules  = require("rules.borders")
local ruled = require("ruled")
require("awful.hotkeys_popup.keys")
--local freedesktop = require("freedesktop")

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
naughty.connect_signal("request::display_error", function(message, startup)
    naughty.notification {
        urgency = "critical",
        title   = "Oops, an error happened"..(startup and " during startup!" or "!"),
        message = message
    }
end)
-- }}}

if awesome.startup_errors then
    naughty.notify(
        {
            preset = naughty.config.presets.critical,
            title = "Oops, there were errors during startup!",
            text = awesome.startup_errors
        }
    )
end



-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal(
        "debug::error",
        function(err)
            -- Make sure we don't go into an endless error loop
            if in_error then
                return
            end
            in_error = true

            naughty.notify(
                {
                    preset = naughty.config.presets.critical,
                    title = "Oops, an error happened!",
                    text = tostring(err)
                }
            )
            in_error = false
        end
    )
end


-- {{{ Variable definitions
-- Themes define colours, icons, font and wallpapers.
beautiful.init(gears.filesystem.get_configuration_dir() .. "theme.lua")
-- local nice = require("nice")
-- nice{
--     titlebar_items = {
--         left = {"close", "minimize", "maximize"},
--         middle = "title",
--         right = {},
--     }
-- }
--beautiful.init(gears.filesystem.get_themes_dir() .. "zenburn/theme.lua")

-- for s in screen do
--     freedesktop.desktop.add_icons({
--         screen = s
--     })
-- end


-- awesome variables
awful.util.terminal = "kitty"
-- awful.screen.focused().tags = {  " ", " ", " ", " ", " ", " ", " ", " ", " ", " "  }
--awful.screen.focused().tags = {"  1:    ", " 2:   ", " 3:    ", " 4:    ", " 5:    ", " 6:   ", " 7:   ", " 8:   ", " 9:   ", "  0:   "}
--awful.screen.focused().tags = {"  1:", " 2:", " 3:", " 4:", " 5:", " 6:", " 7:", " 8:", " 9:", "  0:"}
awful.util.tagnames = {"  1", "  2", "  3", "  4", "  5", "  6", "  7", "  8", "  9", "  0"}

local bling = require("bling")
local layouts = {
    madhur.layout.tallmagnified, -- awesome.layout.suit.tile
    bling.layout.mstab,
    madhur.layout.tallmagnified,
    madhur.layout.threecolmid,           -- bling.layouts.centered
    madhur.layout.centerwork,
    madhur.layout.tallmagnified,
    madhur.layout.tallmagnified,
    madhur.layout.resizedmagnifier,  -- custom written
    madhur.layout.tallmagnified,           --awesome.layout.suit.max
    madhur.layout.threecolmid  -- fork of awesome.layout.suit.magnified , where magnification happens to moster window, not the focused window
}

-- {{{ Tag layout
-- Table of layouts to cover with awful.layout.inc, order matters.
tag.connect_signal("request::default_layouts", function()
    awful.layout.append_default_layouts({
        madhur.layout.tallmagnified,
        bling.layout.mstab,
        madhur.layout.threecolmid,
        madhur.layout.centermaster,
        madhur.layout.grid,
        madhur.layout.resizedmagnifier,
        madhur.layout.max
        -- awful.layout.suit.tile.left
    })
end)
-- }}}

-- Setup global keys
require("keybindings.globalkeys")
-- enable titlebars wherever required
require("widgets.titlebars")



-- Create a wibox for each screen and add it
awful.screen.connect_for_each_screen(
    function(s)
        awful.tag(awful.util.tagnames, s, layouts)
        s.mypromptbox = {}
        s.mypromptbox[s] = awful.widget.prompt()
        -- Setup rules, which will set client keys as well
        awful.rules.rules = require("rules.client_rules")
        awful.screen.focused().tags[2].master_count = 0
        awful.util.smart_wibar_hide = true
        awful.util.expanded = true
        --beautiful.at_screen_connect(s)
        s.mywibox = require("widgets.wiboxes").get(s)
        
    end
)


-- Signal function to execute when a new client appears.
client.connect_signal(
    "manage",
    function(c)
        -- Set the windows at the slave,
        -- i.e. put it at the end of others instead of setting it master.
        if not awesome.startup then
            awful.client.setslave(c)
        end

        if awesome.startup and not c.size_hints.user_position and not c.size_hints.program_position then
            -- Prevent clients from being unreachable after screen count changes.
            awful.placement.no_offscreen(c)
        end

        if c.class == "vlc" then
            awful.client.setmaster(c)
        end

        -- hide tasklist if only single client on tag
        -- if #awful.screen.focused().all_clients  < 2 then
        --     awful.util.mytasklist.visible = false
        -- else
        --     awful.util.mytasklist.visible = true
        -- end
    end
)

client.connect_signal(
    "unmanage",
    function(c)
        -- hide tasklist if only single client on tag
        -- if #awful.screen.focused().all_clients < 2 then
        --     awful.util.mytasklist.visible = false
        -- else
        --     awful.util.mytasklist.visible = true
        -- end
    end
)

tag.connect_signal("property::selected", function()
    -- if #awful.screen.focused().all_clients  < 2 then
    --     awful.util.mytasklist.visible = false
    -- else
    --     awful.util.mytasklist.visible = true
    -- end
end)


client.connect_signal(
    "mouse::enter",
    function(c)
        c:emit_signal(
            "request::activate",
            "mouse_enter",
            {
                raise = true
            }
        )
    end
)

-- keep floating windows on top
client.connect_signal(
    "property::floating",
    function(c)
        if c.floating then
            c.ontop = true
            --awful.titlebar.show(c)
        else
            c.ontop = false
            --awful.titlebar.hide(c)
        end
    end
)

client.connect_signal("focus", border_rules.border_adjust)
--mclient.connect_signal("property::maximized", border_rules.border_adjust)
client.connect_signal(
    "unfocus",
    function(c)
        c.border_color = beautiful.border_normal
    end
)

-- {{{ Notifications

ruled.notification.connect_signal('request::rules', function()
    -- All notifications will match this rule.
    ruled.notification.append_rule {
        rule       = { },
        properties = {
            screen           = awful.screen.preferred,
            implicit_timeout = 5,
        }
    }
end)

naughty.connect_signal("request::display", function(n)
    naughty.layout.box { notification = n }
end)


awful.spawn.with_shell("~/.config/awesome/autostart.sh")

-- naughty.notify {
--     text = "test",
--     position = "middle"
-- }

--- Enable for lower memory consumption
collectgarbage("setpause", 110)
collectgarbage("setstepmul", 1000)
