local awful = require("awful")
local naughty = require("naughty")
local madhur = require("madhur")
local beautiful = require("beautiful")
local markup  = require("lain.util").markup

local switchtag = madhur.widget.switchtag({
    settings = function()
        local icon = nil
        if awful.util.switch_tag then
            icon = "10s"
        else
            icon = "0s"
        end

        widget:set_markup(markup.font(beautiful.font, icon))
    end
})
switchtag.widget:buttons(awful.util.table.join(awful.button({}, 1, function()
    awful.util.switch_tag = not awful.util.switch_tag
    switchtag.update()
end)))

return switchtag