local beautiful = require("beautiful")
local lain = require("lain")
local awful = require("awful")
local markup  = require("lain.util").markup
local naughty = require("naughty")

-- MEM
local mem = lain.widget.mem({
    settings = function()
        widget:set_markup(markup.font(beautiful.font, " " .. mem_now.perc .. " %"))
    end
})

mem.widget:buttons(awful.util.table.join(awful.button({}, 1, function()
    -- left click
    awful.spawn.easy_async_with_shell("conky -c ~/.config/conky/mem.conf", function(stdout, stderr, reason, exit_code)
        naughty.notify {
            text = tostring(stdout)
        }
    end)
end)))

return mem.widget