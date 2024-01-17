local beautiful = require("beautiful")
local awful = require("awful")
local markup  = require("lain.util").markup
local wibox = require("wibox")

local function get_widget(stack_id)
    local widget = awful.widget.watch("/home/madhur/company/f25a24.sh "..stack_id, 300, function(widget, stdout, stderr)
        if tonumber(stdout) > 1 then
            awesome.emit_signal("warning", "aws")
            widget:set_markup(markup.font(beautiful.font, " "..stack_id..":" .. stdout))
        else
            widget:set_markup(markup.font(beautiful.font, ""))
            awesome.emit_signal("normal", "aws")
        end
        
    end)

    return widget
end

local aws = wibox.widget {
    get_widget("pb876a"),
    get_widget("fa84cf"),
    get_widget("a4e71e"),
    get_widget("v3163d"),
    get_widget("v0bfdb"),
    get_widget("f7e408"),
    get_widget("r76f51"),
    get_widget("m60922"),
    layout = wibox.layout.fixed.horizontal,
}

return aws
