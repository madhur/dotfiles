-- Idle Shutdown Widget for AwesomeWM (Circular/Ring Style)
-- Shows remaining time before shutdown as a circular progress indicator
-- Place this file in ~/.config/awesome/widgets/idle-shutdown-ring.lua

local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")

local idle_shutdown_ring = {}

-- Configuration
local IDLE_THRESHOLD_MINUTES = 60
local UPDATE_INTERVAL = 60

-- Create the widget
function idle_shutdown_ring.new()
    local widget = {}
    
    -- Circular progressbar
    widget.arc = wibox.widget {
        min_value = 0,
        max_value = IDLE_THRESHOLD_MINUTES,
        value = 0,
        thickness = 4,
        rounded_edge = true,
        bg = "#333333",
        colors = {"#00ff00"},
        start_angle = math.pi * 1.5,  -- Start at top
        forced_width = 30,
        forced_height = 30,
        widget = wibox.container.arcchart,
    }
    
    -- Icon in the center
    widget.icon = wibox.widget {
        {
            text = "💤",
            align = "center",
            valign = "center",
            font = "Sans 12",
            widget = wibox.widget.textbox,
        },
        forced_width = 30,
        forced_height = 30,
        widget = wibox.container.place,
    }
    
    -- Stack them
    widget.container = wibox.widget {
        widget.icon,
        widget.arc,
        layout = wibox.layout.stack,
    }
    
    -- State
    widget.timer_active = false
    widget.idle_minutes = 0
    
    -- Get idle time
    function widget:get_idle_time(callback)
        awful.spawn.easy_async_with_shell(
            "xprintidle 2>/dev/null",
            function(stdout)
                local idle_ms = tonumber(stdout)
                if idle_ms then
                    callback(math.floor(idle_ms / 60000))
                else
                    callback(nil)
                end
            end
        )
    end
    
 
    -- Check timer status
    -- Check timer status (cleanest approach)
    function widget:check_timer_status(callback)
        awful.spawn.easy_async(
            {"systemctl", "--user", "is-active", "--quiet", "idle-shutdown.timer"},
            function(stdout, stderr, reason, exit_code)
                callback(exit_code == 0)
            end
        )
    end
    
    -- Update display
    function widget:update()
        self:check_timer_status(function(active)
            widget.timer_active = active
            local in_window = true
            
            if not active then
                -- Disabled
                widget.arc.colors = {"#666666"}
                widget.arc.value = 0
                widget.icon.children[1].markup = '<span foreground="#666666">💤</span>'
                widget.container.tooltip_text = "Auto-shutdown: OFF\nClick to enable"
                return
            end
            
            -- Active and in window
            widget:get_idle_time(function(idle_min)
                if not idle_min then
                    widget.icon.children[1].markup = '<span foreground="#ff0000">✗</span>'
                    return
                end
                
                widget.idle_minutes = idle_min
                local remaining = IDLE_THRESHOLD_MINUTES - idle_min
                
                -- Arc value (inverted - depletes as idle time increases)
                widget.arc.value = idle_min
                
                -- Color based on remaining time
                local color
                if remaining > 10 then
                    color = "#00ff00"  -- Green
                elseif remaining > 5 then
                    color = "#ffaa00"  -- Orange
                else
                    color = "#ff0000"  -- Red
                end
                widget.arc.colors = {color}
                
                -- Update icon
                widget.icon.children[1].markup = string.format(
                    '<span foreground="%s" font="Sans 10">%d</span>',
                    color,
                    remaining
                )
                
                -- Tooltip
                widget.container.tooltip_text = string.format(
                    "Auto-shutdown: ACTIVE\n" ..
                    "Idle: %d min\n" ..
                    "Shutdown in: %d min\n" ..
                    "Click to disable",
                    idle_min,
                    remaining
                )
            end)
        end)
    end
    
    -- Toggle function
    -- Toggle function (fixed)
    function widget:toggle()
        awful.spawn.easy_async(
            {"systemctl", "--user", "is-active", "--quiet", "idle-shutdown.timer"},
            function(stdout, stderr, reason, exit_code)
                if exit_code == 0 then
                    -- Timer is active, so stop it
                    awful.spawn.with_shell("systemctl --user stop idle-shutdown.timer && notify-send 'Auto-Shutdown' 'Disabled ❌' -u normal")
                else
                    -- Timer is inactive, so start it
                    awful.spawn.with_shell("systemctl --user start idle-shutdown.timer && notify-send 'Auto-Shutdown' 'Enabled ✅' -u normal")
                end
                gears.timer.start_new(0.5, function()
                    widget:update()
                    return false
                end)
            end
        )
    end
    
    -- Make clickable
    widget.container:buttons(gears.table.join(
        awful.button({}, 1, function() widget:toggle() end)
    ))
    
    -- Initial update
    widget:update()
    
    -- Auto-update
    widget.timer = gears.timer {
        timeout = UPDATE_INTERVAL,
        autostart = true,
        callback = function() widget:update() end
    }
    
    return widget.container
end

return idle_shutdown_ring