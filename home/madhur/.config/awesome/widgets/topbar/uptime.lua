local madhur = require("madhur")
local beautiful = require("beautiful")
local markup  = require("lain.util").markup

local uptime_widget_madhur = madhur.widget.uptime({
    settings = function()
        widget:set_markup(markup.font(beautiful.font, " " .. result))
    end
})

return uptime_widget_madhur.widget

