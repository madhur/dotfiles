local madhur = require("madhur")
local beautiful = require("beautiful")
local markup  = require("lain.util").markup

local notification = madhur.widget.notification({
    settings = function()
        widget:set_markup(markup.font(beautiful.font, result))
    end
})

return notification