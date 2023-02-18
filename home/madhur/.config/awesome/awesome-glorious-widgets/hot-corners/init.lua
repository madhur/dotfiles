----------------------------------------------------------------------------
--- Hot-corners module
--
-- 
-- For more details check my repos README.md
--
--
-- @author manilarome &lt;gerome.matilla07@gmail.com&gt;
-- @copyright 2019 manilarome
-- @module hot-corners
----------------------------------------------------------------------------


local wibox = require('wibox')
local awful = require('awful')
local gears = require('gears')
local naughty = require('naughty')
local beautiful = require('beautiful')

local execute_time = 0.50

local tl_callback = function()
	--naughty.notification({title = 'hot-corner', message='top left'})
end

local tr_callback = function()
	--naughty.notification({title = 'hot-corner', message='top right'})
end

local br_callback = function()
	awful.spawn.with_shell("xscreensaver-command --activate")
	--naughty.notification({title = 'hot-corner', message='bottom right'})
end

local bl_callback = function()
	--naughty.notification({title = 'hot-corner', message='bottom left'})
end

screen.connect_signal("request::desktop_decoration", function(s)

	gears.timer.start_new(0.1, function()

		s.corner_tl = wibox {
			x = s.geometry.x,
			y = s.geometry.y,
			visible = true,
			screen = s,
			ontop = true,
			opacity = 0.0,
			height = 1,
			width = 1,
			type = 'utility'
		}
		local tl_timer = gears.timer {
			timeout   = execute_time,
			call_now  = false,
			autostart = false,
			callback = function(self)
				tl_callback()
				self:stop()
			end
		}
		s.corner_tl:connect_signal(
			"mouse::enter", 
			function()
				if tl_timer.started then
					tl_timer:again()
				else
					tl_timer:start()
				end
	    	end
	    )
		s.corner_tl:connect_signal(
			"mouse::leave", 
			function()
				if tl_timer.started then
					tl_timer:stop()
				end
	    	end
	    )

		s.corner_tr = wibox {
			x = s.geometry.x + (s.geometry.width - 1),
			y = s.geometry.y,
			visible = true,
			screen = s,
			ontop = true,
			opacity = 0.0,
			height = 1,
			width = 1,
			type = 'utility'
		}
		local tr_timer = gears.timer {
			timeout   = execute_time,
			call_now  = false,
			autostart = false,
			callback = function(self)
				tr_callback()
				self:stop()
			end
		}
		s.corner_tr:connect_signal(
			"mouse::enter", 
			function()
				if tr_timer.started then
					tr_timer:again()
				else
					tr_timer:start()
				end
	    	end
	    )
		s.corner_tr:connect_signal(
			"mouse::leave", 
			function()
				if tr_timer.started then
					tr_timer:stop()
				end
	    	end
	    )

		s.corner_br = wibox {
			x = s.geometry.x + (s.geometry.width - 1),
			y = s.geometry.y + (s.geometry.height - 1),
			visible = true,
			screen = s,
			ontop = true,
			opacity = 0.0,
			height = 1,
			width = 1,
			type = 'utility'
		}
		local br_timer = gears.timer {
			timeout   = execute_time,
			call_now  = false,
			autostart = false,
			callback = function(self)
				br_callback()
			    self:stop()
			end
		}
		s.corner_br:connect_signal(
			"mouse::enter", 
			function()
				if br_timer.started then
					br_timer:again()
				else
					br_timer:start()
				end
	    	end
	    )
		s.corner_br:connect_signal(
			"mouse::leave", 
			function()
				if br_timer.started then
					br_timer:stop()
				end
	    	end
	    )

		s.corner_bl = wibox {
			x = s.geometry.x,
			y = s.geometry.y + (s.geometry.height - 1),
			visible = true,
			screen = s,
			ontop = true,
			opacity = 0.0,
			height = 1,
			width = 1,
			type = 'utility'
		}
		local bl_timer = gears.timer {
			timeout   = execute_time,
			call_now  = false,
			autostart = false,
			callback = function(self)
				bl_callback()
				self:stop()
			end
		}
		s.corner_bl:connect_signal(
			"mouse::enter", 
			function()
				if bl_timer.started then
					bl_timer:again()
				else
					bl_timer:start()
				end
	    	end
	    )
		s.corner_bl:connect_signal(
			"mouse::leave", 
			function()
				if bl_timer.started then
					bl_timer:stop()
				end
	    	end
	    )

	end)

end)


-- A hack to always put the hot-corners on top
-- Pretty nasty code, eh?
-- Please, PR if you can improve this.
local move_to_top = function()
	focused = awful.screen.focused()

	local tl = focused.corner_tl
	local tr = focused.corner_tr
	local br = focused.corner_br
	local bl = focused.corner_bl

	tl.ontop = true
	tl.visible = false
	tl.visible = true

	tr.ontop = true
	tr.visible = false
	tr.visible = true

	br.ontop = true
	br.visible = false
	br.visible = true

	bl.ontop = true
	bl.visible = false
	bl.visible = true
end


client.connect_signal(
	"property::fullscreen", 
	function(c)
		move_to_top()
	end
)
