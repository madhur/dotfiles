local beautiful = require("beautiful")
local lain = require("lain")
local awful = require("awful")
local markup  = require("lain.util").markup

local fs = lain.widget.fs({
    partition = "/",
    notification_preset = {
        fg = beautiful.fg_normal,
        bg = beautiful.bg_normal,
        font = beautiful.font
    },
    settings = function()
        local fsp = string.format(" %d %s", fs_now["/"].percentage, "%")
        widget:set_markup(markup.font(beautiful.font, " " .. fsp))
    end
})
-- ]]

return fs.widget