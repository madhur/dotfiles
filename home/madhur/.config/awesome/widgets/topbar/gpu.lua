local madhur = require("madhur")
local markup  = require("lain.util").markup

local mygpu = madhur.widget.nvidia({
    settings = function()
        widget:set_markup(markup.font(beautiful.font, " " .. gpu.usage .. " " .. gpu.temp .. "°C"))
    end
})
