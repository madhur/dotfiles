-- XScreensaver Timeout Widget for AwesomeWM (Circular/Ring Style)
-- Shows remaining time before xscreensaver activates as a circular progress indicator

local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")

local xscreensaver_ring = {}

-- Configuration
local UPDATE_INTERVAL = 30

-- Create the widget
function xscreensaver_ring.new()
    local widget = {}

    -- Default timeout (will be updated from xscreensaver settings)
    widget.timeout_minutes = 10

    -- Circular progressbar
    widget.arc = wibox.widget {
        min_value = 0,
        max_value = widget.timeout_minutes,
        value = 0,
        thickness = 4,
        rounded_edge = true,
        bg = "#333333",
        colors = {"#00aaff"},
        start_angle = math.pi * 1.5,  -- Start at top
        forced_width = 30,
        forced_height = 30,
        widget = wibox.container.arcchart,
    }

    -- Icon/text in the center
    widget.icon = wibox.widget {
        {
            text = "",
            align = "center",
            valign = "center",
            font = "Sans 10",
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
    widget.idle_minutes = 0
    widget.screensaver_enabled = true

    -- Get xscreensaver timeout from config
    function widget:get_timeout(callback)
        awful.spawn.easy_async_with_shell(
            "grep -E '^timeout:' ~/.xscreensaver 2>/dev/null | awk '{print $2}'",
            function(stdout)
                -- Format is HH:MM:SS
                local time_str = stdout:match("(%d+:%d+:%d+)")
                if time_str then
                    local h, m, s = time_str:match("(%d+):(%d+):(%d+)")
                    local total_minutes = (tonumber(h) or 0) * 60 + (tonumber(m) or 0)
                    if total_minutes > 0 then
                        callback(total_minutes)
                        return
                    end
                end
                callback(10) -- Default to 10 minutes
            end
        )
    end

    -- Get idle time using xprintidle
    function widget:get_idle_time(callback)
        awful.spawn.easy_async_with_shell(
            "xprintidle 2>/dev/null",
            function(stdout)
                local idle_ms = tonumber(stdout)
                if idle_ms then
                    callback(idle_ms / 60000) -- Return as decimal minutes
                else
                    callback(nil)
                end
            end
        )
    end

    -- Check if xscreensaver is running
    function widget:check_status(callback)
        awful.spawn.easy_async_with_shell(
            "xscreensaver-command -time 2>&1",
            function(stdout)
                local is_blanked = stdout:match("screen blanked") ~= nil
                local is_locked = stdout:match("screen locked") ~= nil
                local is_running = stdout:match("screen non%-blanked") ~= nil or is_blanked or is_locked
                callback(is_running, is_blanked or is_locked)
            end
        )
    end

    -- Update display
    function widget:update()
        self:get_timeout(function(timeout_min)
            widget.timeout_minutes = timeout_min
            widget.arc.max_value = timeout_min

            self:check_status(function(running, blanked)
                if not running then
                    -- xscreensaver not running
                    widget.arc.colors = {"#666666"}
                    widget.arc.value = 0
                    widget.icon.children[1].markup = '<span foreground="#666666"></span>'
                    widget.container.tooltip_text = "XScreensaver: NOT RUNNING"
                    return
                end

                if blanked then
                    -- Screen is blanked/locked
                    widget.arc.colors = {"#ff6600"}
                    widget.arc.value = timeout_min
                    widget.icon.children[1].markup = '<span foreground="#ff6600"></span>'
                    widget.container.tooltip_text = "Screen: LOCKED"
                    return
                end

                -- Get current idle time
                widget:get_idle_time(function(idle_min)
                    if not idle_min then
                        widget.icon.children[1].markup = '<span foreground="#ff0000">?</span>'
                        return
                    end

                    widget.idle_minutes = idle_min
                    local remaining = timeout_min - idle_min
                    if remaining < 0 then remaining = 0 end

                    -- Arc value (shows how much idle time has passed)
                    widget.arc.value = idle_min

                    -- Color based on remaining time
                    local color
                    if remaining > timeout_min * 0.5 then
                        color = "#00aaff"  -- Blue (plenty of time)
                    elseif remaining > timeout_min * 0.25 then
                        color = "#ffaa00"  -- Orange (getting close)
                    else
                        color = "#ff0000"  -- Red (about to blank)
                    end
                    widget.arc.colors = {color}

                    -- Update icon with remaining minutes
                    local display_remaining = math.ceil(remaining)
                    widget.icon.children[1].markup = string.format(
                        '<span foreground="%s" font="Sans 10">%d</span>',
                        color,
                        display_remaining
                    )

                    -- Tooltip
                    widget.container.tooltip_text = string.format(
                        "XScreensaver Timeout: %d min\n" ..
                        "Idle: %.1f min\n" ..
                        "Blanks in: %d min\n" ..
                        "Click to activate now",
                        timeout_min,
                        idle_min,
                        display_remaining
                    )
                end)
            end)
        end)
    end

    -- Activate screensaver now
    function widget:activate()
        awful.spawn.with_shell("xscreensaver-command -activate")
    end

    -- Deactivate screensaver (unlock)
    function widget:deactivate()
        awful.spawn.with_shell("xscreensaver-command -deactivate")
    end

    -- Make clickable
    widget.container:buttons(gears.table.join(
        awful.button({}, 1, function() widget:activate() end),
        awful.button({}, 3, function() widget:deactivate() end)
    ))

    -- Tooltip
    local tooltip = awful.tooltip {
        objects = {widget.container},
        delay_show = 0.5,
    }

    widget.container.tooltip_text = "XScreensaver"
    widget.container:connect_signal("mouse::enter", function()
        tooltip.text = widget.container.tooltip_text
    end)

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

return xscreensaver_ring
