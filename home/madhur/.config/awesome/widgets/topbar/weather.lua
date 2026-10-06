local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local weather_widget = require("awesome-wm-widgets.weather-widget.weather")

local api_key = os.getenv("OWM_API_KEY")

-- Bengaluru coordinates: 12.9716, 77.5946
local weather_bengaluru = weather_widget({
    api_key = api_key,
    coordinates = {12.9716, 77.5946},
    units = 'metric',
    show_hourly_forecast = true,
    show_daily_forecast = true,
    timeout = 3600,  -- refresh every hour
})

-- Delhi coordinates: 28.6139, 77.2090
local weather_delhi = weather_widget({
    api_key = api_key,
    coordinates = {28.6139, 77.2090},
    units = 'metric',
    show_hourly_forecast = true,
    show_daily_forecast = true,
    timeout = 3600,  -- refresh every hour
})

local weather_combined = wibox.widget {
    {
        {
            markup = "<b>BLR</b>",
            widget = wibox.widget.textbox,
        },
        weather_bengaluru,
        spacing = 4,
        layout = wibox.layout.fixed.horizontal,
    },
    {
        {
            markup = "<b>DEL</b>",
            widget = wibox.widget.textbox,
        },
        weather_delhi,
        spacing = 4,
        layout = wibox.layout.fixed.horizontal,
    },
    spacing = 10,
    layout = wibox.layout.fixed.horizontal,
}

weather_combined:buttons(gears.table.join(
    awful.button({}, 3, function()
        weather_bengaluru:refresh()
        weather_delhi:refresh()
    end)
))

return weather_combined
