-- Screenshot Timeline Toggle Widget for AwesomeWM
-- Toggles periodic screenshot capture by creating/removing a flag file

local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")

local screenshot_toggle = {}

local FLAG_FILE = "/tmp/screenshot-timeline-disabled"

function screenshot_toggle.new()
    local widget = {}

    widget.icon = wibox.widget {
        markup = '<span foreground="#00ff00">󰄀</span>',
        align = "center",
        valign = "center",
        font = "Nerd Font 14",
        widget = wibox.widget.textbox,
    }

    widget.container = wibox.widget {
        widget.icon,
        forced_width = 30,
        forced_height = 30,
        widget = wibox.container.place,
    }

    widget.enabled = true

    function widget:check_status()
        -- If flag file exists, screenshots are disabled
        local f = io.open(FLAG_FILE, "r")
        if f then
            f:close()
            return false  -- disabled
        end
        return true  -- enabled
    end

    function widget:update()
        widget.enabled = self:check_status()
        if widget.enabled then
            widget.icon.markup = '<span foreground="#00ff00">󰄀</span>'
            widget.container.tooltip_text = "Timeline Screenshots: ON\nClick to disable"
        else
            widget.icon.markup = '<span foreground="#666666">󰄀</span>'
            widget.container.tooltip_text = "Timeline Screenshots: OFF\nClick to enable"
        end
    end

    function widget:toggle()
        if self:check_status() then
            -- Currently enabled, disable it
            local f = io.open(FLAG_FILE, "w")
            if f then
                f:write("disabled")
                f:close()
            end
            awful.spawn.with_shell("notify-send 'Timeline Screenshots' 'Disabled' -u normal")
        else
            -- Currently disabled, enable it
            os.remove(FLAG_FILE)
            awful.spawn.with_shell("notify-send 'Timeline Screenshots' 'Enabled' -u normal")
        end
        self:update()
    end

    widget.container:buttons(gears.table.join(
        awful.button({}, 1, function() widget:toggle() end)
    ))

    local tooltip = awful.tooltip {
        objects = {widget.container},
        delay_show = 0.5,
    }

    widget.container.tooltip_text = "Timeline Screenshots"
    widget.container:connect_signal("mouse::enter", function()
        tooltip.text = widget.container.tooltip_text
    end)

    widget:update()

    return widget.container
end

return screenshot_toggle
