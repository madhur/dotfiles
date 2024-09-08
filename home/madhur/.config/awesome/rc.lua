local awesome, client, tag = awesome, client, tag
local tostring = tostring
local awful = require("awful")
local gears = require("gears")
require("awful.autofocus")
local beautiful = require("beautiful")
local lain = require("lain")
local naughty = require("naughty")
local madhur = require("madhur")
local ruled = require("ruled")
require("awful.hotkeys_popup.keys")

naughty.connect_signal("request::display_error", function(message, startup)
	naughty.notification({
		urgency = "critical",
		title = "Oops, an error happened" .. (startup and " during startup!" or "!"),
		message = message,
	})
end)

if awesome.startup_errors then
	naughty.notify({
		preset = naughty.config.presets.critical,
		title = "Oops, there were errors during startup!",
		text = awesome.startup_errors,
	})
end

-- Handle runtime errors after startup
do
	local in_error = false
	awesome.connect_signal("debug::error", function(err)
		-- Make sure we don't go into an endless error loop
		if in_error then
			return
		end
		in_error = true

		naughty.notify({
			preset = naughty.config.presets.critical,
			title = "Oops, an error happened!",
			text = tostring(err),
		})
		in_error = false
	end)
end

beautiful.init(gears.filesystem.get_configuration_dir() .. "theme.lua")
-- awesome variables
awful.util.terminal = "kitty"
awful.util.tagnames = { "  1", "  2", "  3", "  4", "  5", "  6", "  7", "  8", "  9", "  0" }

local bling = require("bling")
local layouts = {
	awful.layout.suit.max, -- Like tall layout, master on left
	awful.layout.suit.max, -- three col mid
	awful.layout.suit.max, -- Like tall layout, master on left
--	awful.layout.suit.tile.right, -- three col mid
    awful.layout.suit.max,
	awful.layout.suit.max,
    awful.layout.suit.max,
    awful.layout.suit.max,
    awful.layout.suit.max,
	--lain.layout.termfair.center, -- Like tall layout, master on left
	--awful.layout.suit.tile.right, -- three col mid
	--lain.layout.termfair.center, -- Like tall layout, master on left
	
	bling.layout.equalarea, -- grid
	bling.layout.deck,
}

tag.connect_signal("request::default_layouts", function()
	awful.layout.append_default_layouts({
		awful.layout.suit.tile.right,
		awful.layout.suit.tile.bottom,
		bling.layout.deck,
		bling.layout.equalarea,
		awful.layout.suit.max,
		bling.layout.mstab,
	})
end)

-- Setup global keys
require("keybindings.globalkeys")
-- enable titlebars wherever required
-- require("widgets.titlebars")

awful.util.smart_wibar_hide = false
awful.util.expanded = true
awful.util.vertical_expanded = false

-- Create a wibox for each screen and add it
awful.screen.connect_for_each_screen(function(s)
	awful.tag(awful.util.tagnames, s, layouts)

	awful.rules.rules = require("rules.client_rules") -- if this call is outside of this block, the  programs starting will not move to tags correctly accoring to rules
	--awful.screen.focused().tags[3].master_count = 0
	s.mywibox = require("widgets.wiboxes").get(s)
	
	-- If its a portrait monitor, add some gap on top because my portrait monitor is too high, else my neck hurts
	if s.geometry.width == 2160 and s.geometry.height == 3840 then
		s.padding = {
			left = 0,
			right = 0,
			top = 600,
			bottom = 0
		}
	end
end)

-- Signal function to execute when a new client appears.
client.connect_signal("manage", function(c)
	-- Set the windows at the slave,
	-- i.e. put it at the end of others instead of setting it master.
	if not awesome.startup then
		awful.client.setslave(c)
	end

	if awesome.startup and not c.size_hints.user_position and not c.size_hints.program_position then
		-- Prevent clients from being unreachable after screen count changes.
		awful.placement.no_offscreen(c)
	end

	-- if c.class == "vlc" then
	-- 	awful.client.setmaster(c)
	-- end
end)

client.connect_signal("mouse::enter", function(c)
	c:emit_signal("request::activate", "mouse_enter", {
		raise = true,
	})
end)

ruled.notification.connect_signal("request::rules", function()
	-- All notifications will match this rule.
	ruled.notification.append_rule({
		rule = {},
		properties = {
			screen = awful.screen.preferred,
			implicit_timeout = 5,
		},
	})
end)

naughty.connect_signal("request::display", function(n)
	naughty.layout.box({
		notification = n,
	})
end)

client.connect_signal("focus", function(c)
	c.border_color = beautiful.border_focus
end)
client.connect_signal("unfocus", function(c)
	c.border_color = beautiful.border_normal
end)

-- Remove border when only one window
local function set_border(c)
	local s = awful.screen.focused()
	if
		c.maximized
		or (#s.tiled_clients == 1 and not c.floating)
		or (s.selected_tag and s.selected_tag.layout.name == "max")
	then
		c.border_width = 0
	else
		c.border_width = beautiful.border_width
	end
end

client.connect_signal("request::border", set_border)
client.connect_signal("property::maximized", set_border)

awful.spawn.with_shell("~/scripts/autostart.sh")
--- Enable for lower memory consumption
collectgarbage("setpause", 110)
collectgarbage("setstepmul", 1000)
