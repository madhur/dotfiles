
-- uptime info
-- madhur.widget.uptime
local timer  = require("gears.timer")
local spawn  = require("awful.spawn")
local wibox    = require("wibox")
local helpers = require("madhur.helpers")
local tonumber = tonumber



local GOVERNOR_STATE = {
    ["ondemand\n"]     = "↯",
    ["schedutil\n"]     = "↯",
    ["powersave\n"]    = "⌁",
    ["userspace\n"]    = "¤",
    ["performance\n"]  = "⚡",
    ["conservative\n"] = "⊚"
}

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

    local cpufreq     = { widget = args.widget or wibox.widget.textbox() }
    local timeout  = args.timeout or 2
    local settings = args.settings or function() end

    function cpufreq.update()

        local _cpufreq = helpers.pathtotable(
            ("/sys/devices/system/cpu/%s/cpufreq"):format("cpu0"))
        -- Default frequency and voltage values
        freqv = {
            ["mhz"] = "N/A", ["ghz"] = "N/A",
            ["v"]   = "N/A", ["mv"]  = "N/A",
        }
    
        -- Get the current frequency
        local freq = tonumber(_cpufreq.scaling_cur_freq)
        -- Calculate MHz and GHz
        if freq then
            freqv.mhz = freq / 1000
            freqv.ghz = freqv.mhz / 1000
            freqv.ghz = tonumber(string.format("%.1f", freqv.ghz))
    
            -- Get the current voltage
            if _cpufreq.scaling_voltages then
                freqv.mv = tonumber(
                    _cpufreq.scaling_voltages:match(freq .. "[%s]([%d]+)"))
                -- Calculate voltage from mV
                freqv.v  = freqv.mv / 1000
            end
        end
    
        if freqv.ghz >= 4.5 then
            awesome.emit_signal("warning", "cpufreq")    
        elseif freqv.ghz < 3.0 then
            awesome.emit_signal("normal", "cpufreq")    
        else
            awesome.emit_signal("normal", "cpufreq")    
        end
        -- Get the current governor
        governor = _cpufreq.scaling_governor
        -- Represent the governor as a symbol
        governor = GOVERNOR_STATE[governor] or governor or "N/A"
    
        
        widget = cpufreq.widget

    settings()
    end
    newtimer("cpufreq", timeout, cpufreq.update)
    return cpufreq
end



return factory