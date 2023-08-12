local beautiful = require("beautiful")
local awful = require("awful")
local markup  = require("lain.util").markup

local edd7b0 = awful.widget.watch("/home/madhur/company/f25a24.sh edd7b0", 5, function(widget, stdout, stderr)
    if tonumber(stdout) > 1 then
        awesome.emit_signal("warning", "edd7b0")
        widget:set_markup(markup.font(beautiful.font, " edd7b0:" .. stdout))
    else
        awesome.emit_signal("normal", "edd7b0")
    end
    
end)

return edd7b0
