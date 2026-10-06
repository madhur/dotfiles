local wibox = require("wibox")
local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")

-- Create the caps lock widget
local capslock_widget = {}

-- Create the text widget
local capslock_text = wibox.widget {
    text = "CAPS",
    align = "center",
    valign = "center",
    font = beautiful.font or "sans 9",
    widget = wibox.widget.textbox,
}

-- Create the container widget with background
local capslock_container = wibox.widget {
    capslock_text,
    left = 8,
    right = 8,
    top = 2,
    bottom = 2,
    widget = wibox.container.margin,
}

-- Function to check caps lock status
local function get_capslock_status()
    awful.spawn.easy_async_with_shell("xset q | grep 'Caps Lock' | awk '{print $4}'", function(stdout)
        local status = stdout:gsub("%s+", "") -- Remove whitespace
        local is_on = status == "on"
        
        if is_on then
            -- Caps Lock is ON - make it prominent
            capslock_text:set_markup('<span foreground="#ff6b6b" weight="bold">CAPS</span>')
            capslock_container.bg = "#ff6b6b22" -- Light red background
        else
            -- Caps Lock is OFF - make it subtle
            capslock_text:set_markup('<span foreground="#666666">caps</span>')
            capslock_container.bg = "transparent"
        end
        
        -- Emit signal with caps lock state for visibility control
        awesome.emit_signal("capslock::status", is_on)
    end)
end

-- Update the widget initially
get_capslock_status()

-- Set up a timer to check caps lock status periodically
local capslock_timer = gears.timer {
    timeout = 1, -- Check every second
    autostart = true,
    callback = get_capslock_status
}

-- Add click functionality to toggle caps lock
capslock_container:buttons(gears.table.join(
    awful.button({}, 1, function()
        awful.spawn("xdotool key Caps_Lock")
        -- Update immediately after toggle
        gears.timer.delayed_call(get_capslock_status)
    end)
))

-- Add tooltip
local capslock_tooltip = awful.tooltip {
    objects = { capslock_container },
    text = "Caps Lock Status\nClick to toggle"
}

-- Export the widget
capslock_widget.widget = capslock_container
capslock_widget.update = get_capslock_status

return capslock_widget