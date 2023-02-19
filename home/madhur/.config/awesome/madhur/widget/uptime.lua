
-- uptime info
-- madhur.widget.uptime
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

local function split(s, sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    s:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

local function factory(args)
    args           = args or {}

    local uptime     = { widget = args.widget or wibox.widget.textbox() }
    local timeout  = args.timeout or 60
    local settings = args.settings or function() end

    function uptime.update()
        spawn.easy_async("cat /proc/uptime", function (stdout, stderr, reason, exit_code)
            if stdout == nil then
                return
            end
            local output = stdout
            local splits = split(output, ".")
            if next(splits) == nil then
                -- myTable is empty
                return nil
            end
            local seconds = tonumber(splits[1])
            local weeks = seconds // 604800
            seconds = seconds % 604800
            local days = seconds // 86400
            seconds = seconds % 86400
            local hours = seconds // 3600
            seconds = seconds % 3600
            local minutes = seconds // 60
            seconds = seconds % 60
            result = nil 
            if weeks >= 1 
            then
                result = string.format("%dw %dd", weeks, days)
            elseif days >= 1 
            then
                result = string.format("%dd %dh", days, hours)
            elseif hours >= 1 
            then
                result = string.format("%dh %dm", hours, minutes)
            else
                result = string.format("%dh %dm", hours, minutes)
            end
            widget = uptime.widget

            awesome.emit_signal("normal", "uptime")

            settings()
        end)
    end
    newtimer("uptime", timeout, uptime.update)
    return uptime
end



return factory