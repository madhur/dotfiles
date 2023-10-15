local beautiful = require("beautiful")
local lain = require("lain")
local awful = require("awful")
local markup = require("lain.util").markup
local naughty = require("naughty")
local floor = require("math").floor

-- MEM
local mem = lain.widget.mem({
	settings = function()
		widget:set_markup(markup.font(beautiful.font, " " .. floor(mem_now.used/1024) .. " GB"))
	end,
})

mem.widget:buttons(awful.util.table.join(
	awful.button({}, 1, function()
		-- left click
		awful.spawn.easy_async_with_shell("conky -c ~/.config/conky/mem.conf", function(stdout, _, _, _)
			naughty.notify({
				text = tostring(stdout),
			})
		end)
	end),
	awful.button({}, 3, function()
		-- right click
		local text = "Used: "
			.. floor(mem_now.used / 1024)
			.. " GB\nFree: "
			.. floor(mem_now.free / 1204)
			.. " GB\nBuf: "
			.. floor(mem_now.buf / 1024)
			.. " GB\nCache: "
			.. floor(mem_now.cache / 1024)
			.. " GB\nSRec: "
			.. floor(mem_now.srec / 1024)
			.. " GB"
		naughty.notify({
			text = tostring(text),
		})
	end)
))

return mem.widget
