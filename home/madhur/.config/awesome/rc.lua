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


-- awesome variables
awful.util.terminal = "kitty"
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
        --bling.layout.mstab,
        madhur.layout.threecolmid,
        awful.layout.suit.floating,
        --madhur.layout.centermaster,
        awful.layout.suit.magnifier,
        awful.layout.suit.max,
        awful.layout.suit.max.fullscreen,
        --madhur.layout.grid,
       -- madhur.layout.resizedmagnifier,
        --madhur.layout.max,
        awful.layout.fullscreen,
       
        -- awful.layout.suit.tile.left
    })
end)
-- }}}

-- Setup global keys
require("keybindings.globalkeys")
-- enable titlebars wherever required
--require("widgets.titlebars")

-- Setup rules, which will set client keys as well


awful.util.smart_wibar_hide = false
awful.util.expanded = true

-- Create a wibox for each screen and add it
awful.screen.connect_for_each_screen(
    function(s)
        awful.tag(awful.util.tagnames, s, layouts)
        
        
        awful.rules.rules = require("rules.client_rules") -- if this call is outside of this block, the  programs starting will not move to tags correctly accoring to rules
        awful.screen.focused().tags[2].master_count = 0
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
    end
)



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


awful.spawn.with_shell("~/scripts/autostart.sh")


--- Enable for lower memory consumption
collectgarbage("setpause", 110)
collectgarbage("setstepmul", 1000)
