
-- Temperature info
-- madhur.widget.temp
local timer  = require("gears.timer")
local spawn  = require("awful.spawn")
local wibox    = require("wibox")
local tonumber = tonumber

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

    local temp     = { widget = args.widget or wibox.widget.textbox() }
    local timeout  = args.timeout or 5
    local settings = args.settings or function() end
    local warn_count = 0
    local crit_count = 0

    function temp.update()
        spawn.easy_async_with_shell("sensors | grep Tctl: | cut -c 16-19", function (stdout, stderr, reason, exit_code)
            -- naughty.notify({text=stderr})
            if stdout == nil then
                return
            end
            result = stdout
            widget = temp.widget
            if tonumber(result) > 90 then
                crit_count  =  crit_count + 1
                awesome.emit_signal("critical", "temp")
            elseif tonumber(result) > 60 then
                warn_count = warn_count + 1
                awesome.emit_signal("warning", "temp")            
            else
                warn_count = 0
                crit_count = 0
                awesome.emit_signal("normal", "temp")            
            end

            settings()
        end)
    end
    
    newtimer("temp", timeout, temp.update)
    
    return temp
end

return factory