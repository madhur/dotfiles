local beautiful = require("beautiful")
local awful = require("awful")
local markup  = require("lain.util").markup
local wibox = require("wibox")

local function get_widget(stack_id)
    local widget = awful.widget.watch("/home/madhur/company/f25a24.sh "..stack_id, 5, function(widget, stdout, stderr)
        if tonumber(stdout) > 1 then
            awesome.emit_signal("warning", stack_id)
            widget:set_markup(markup.font(beautiful.font, " "..stack_id..":" .. stdout))
        else
            awesome.emit_signal("normal", stack_id)
        end
        
    end)

    return widget
end

local aws = wibox.widget {
    get_widget("edd7b0"),
    get_widget("a647b7"),
    layout = wibox.layout.fixed.horizontal,
}

return aws