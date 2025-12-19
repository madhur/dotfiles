local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local markup  = require("lain.util").markup
local naughty = require("naughty")

local redshift_widget = wibox.widget.textbox()

-- Function to convert color temperature to RGB
local function temp_to_rgb(temp)
    -- Clamp temperature between 1000K and 12000K
    temp = math.max(1000, math.min(12000, temp))
    
    -- Convert temperature to RGB using a simplified approximation
    local r, g, b = 255, 255, 255
    
    if temp <= 6600 then
        -- Red component
        r = 255
        -- Green component
        g = 99.4708025861 * math.log(temp/100) - 161.1195681661
        -- Blue component
        if temp <= 1900 then
            b = 0
        else
            b = 138.5177312231 * math.log(temp/100 - 10) - 305.0447927307
        end
    else
        -- Red component
        r = 329.698727446 * math.pow(temp/100 - 60, -0.1332047592)
        -- Green component
        g = 288.1221695283 * math.pow(temp/100 - 60, -0.0755148492)
        -- Blue component
        b = 255
    end
    
    -- Clamp values between 0 and 255
    r = math.max(0, math.min(255, r))
    g = math.max(0, math.min(255, g))
    b = math.max(0, math.min(255, b))
    
    -- Convert to hex
    return string.format("#%02x%02x%02x", math.floor(r), math.floor(g), math.floor(b))
end

local function update_widget(widget, stdout)
    local temp = stdout:match("Color temperature:%s*(%d+)%s*K")
    if temp then
        local temp_num = tonumber(temp)
        local color = temp_to_rgb(temp_num)
        widget:set_markup(" " .. markup.font(beautiful.font, "<span foreground='" .. color .. "'> " .. temp .. "K</span>"))
        -- Emit signal with temperature for visibility control
        awesome.emit_signal("redshift::temperature", temp_num)
    else
        widget:set_markup(" " .. markup.font(beautiful.font, "<span foreground='#ffffff'> N/A</span>"))
        -- Emit signal with nil/unknown temperature
        awesome.emit_signal("redshift::temperature", nil)
    end
end

awful.widget.watch(
    "redshift -p", 30, update_widget, redshift_widget
)

return redshift_widget 