
-- uptime info
-- madhur.widget.uptime
local timer  = require("gears.timer")
local spawn  = require("awful.spawn")
local wibox    = require("wibox")
local helpers = require("madhur.helpers")
local tonumber = tonumber
local awful = require("awful")
local lain = require("lain")



local timer_table = {}
local function newtimer(name, timeout, fun, nostart, stoppable)
    if not name or #name == 0 then return end
    name = (stoppable and name) or timeout
    if not timer_table[name] then
        timer_table[name] = timer({ timeout = timeout })
        timer_table[name]:start()
    end
    timer_table[name]:connect_signal("timeout", fun)
    if not nostart then
        timer_table[name]:emit_signal("timeout")
    end
    return stoppable and timer_table[name]
end

local function factory(args)
    args           = args or {}

    local switchtag     = { widget = args.widget or wibox.widget.textbox() }
    local timeout  = args.timeout or 5
    local settings = args.settings or function() end

    function switchtag.update()

       if awful.util.switch_tag then
        
        lain.util.tag_view_nonempty(1) 
       end
    
        
        widget = switchtag.widget
        widget.settings = settings
    settings()
    end
    newtimer("switchtag", timeout, switchtag.update)
    return switchtag
end



return factory