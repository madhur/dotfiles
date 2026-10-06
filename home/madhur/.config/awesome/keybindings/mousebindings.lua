local awful = require("awful")
local gears = require("gears")
local modkey = "Mod4"
local altkey = "Mod1"
local ctrlkey = "Control"
local shiftkey = "Shift"

local mousebindings =
gears.table.join(
awful.button(
    {},
    1,
    function(c)
        c:emit_signal(
            "request::activate",
            "mouse_click",
            {
                raise = true
            }
        )
    end
),
awful.button(
    {modkey},
    1,
    function(c)
        c:emit_signal(
            "request::activate",
            "mouse_click",
            {
                raise = true
            }
        )
        awful.mouse.client.move(c)
    end
),
awful.button(
    {},
    2,
    function(c)
        c:emit_signal(
            "request::activate",
            "mouse_click",
            {
                raise = true
            }
        )
        c:kill()
    end
),
awful.button(
    {modkey},
    3,
    function(c)
        c:emit_signal(
            "request::activate",
            "mouse_click",
            {
                raise = true
            }
        )
        awful.mouse.client.resize(c)
    end
)
)

return mousebindings
