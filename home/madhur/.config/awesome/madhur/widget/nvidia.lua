--[[
     Licensed under GNU General Public License v2
      * (c) 2013, Luca CPZ
      * (c) 2022, tronfy <https://github.com/tronfy>
--]]

local wibox    = require("wibox")
local timer  = require("gears.timer")
local spawn = require("awful.spawn")
local timer_table = {}
-- NVIDIA GPU usage/temperature info (requires nvidia-smi)
-- lain.widget.contrib.nvidia

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

    local nvidia   = { widget = args.widget or wibox.widget.textbox() }
    local timeout  = args.timeout or 5
    local exec     = args.exec or "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits"
    local format   = args.format or "%.1f"
    local settings = args.settings or function() end

    function nvidia.update()
        gpu = {
            usage = "N/A",
            temp  = "N/A"
        }

        spawn.easy_async(exec, function(f)
            -- f -> "usage, temp"
            gpu.usage, gpu.temp = f:match("([^,]+),([^,]+)")
            gpu.temp = string.format(format, gpu.temp)

            if tonumber(gpu.temp) >= 90 then
                awesome.emit_signal("critical", "gpu")
            elseif tonumber(gpu.temp) >= 65 then
               awesome.emit_signal("warning", "gpu")            
            else
                awesome.emit_signal("normal", "gpu")            
            end
            widget = nvidia.widget
            settings()
        end)
    end

    newtimer("nvidia-gpu", timeout, nvidia.update)

    return nvidia
end

return factory