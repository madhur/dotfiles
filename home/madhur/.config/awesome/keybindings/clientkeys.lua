
local awful = require("awful")
local lain = require("lain")
local bling =  require("bling")
local madhur = require("madhur")
local gears = require("gears")
local config = require("config")
local modkey = "Mod4"
local altkey = "Mod1"
local shiftkey = "Shift"


local clientkeys =
gears.table.join(
awful.key(
    {altkey, shiftkey},
    "space",
    lain.util.magnify_client,
    {
        description = "magnify client",
        group = "client"
    }
),
awful.key(
    {modkey},
    "f",
    function(c)
        c.fullscreen = not c.fullscreen
        c:raise()

        --c.maximized = not c.maximized
       -- c:raise()
    end,
    {
        description = "toggle fullscreen",
        group = "client"
    }
),
awful.key(
    {modkey},
    "r",
    function(c)
        c:raise()
    end,
    {
        description = "Raise window",
        group = "client"
    }
),
awful.key(
    {modkey,},
    "m",
    function(c)
        c.maximized = not c.maximized
        c:raise()
    end,
    {
        description = "toggle maximize",
        group = "client"
    }
),
awful.key(
    {modkey, shiftkey},
    "c",
    function(c)
        c:kill()
    end,
    {
        description = "close",
        group = "client"
    }
),
awful.key(
    {modkey, shiftkey},
    "space",
    awful.client.floating.toggle,
    {
        description = "toggle floating",
        group = "client"
    }
),
awful.key(
    {modkey},
    "t",
    function(c)
        c.floating = false
    end,
    {
        description = "make tiled",
        group = "client"
    }
),
awful.key(
    {modkey, shiftkey},
    "m",
    function(c)
        c:swap(awful.client.getmaster())
    end,
    {
        description = "move to master",
        group = "client"
    }
),
awful.key(
    {modkey, shiftkey},
    "t",
    function(c)
        c.ontop = not c.ontop
    end,
    {
        description = "toggle keep on top",
        group = "client"
    }
),
awful.key(
    {modkey},
    "o",
    function(c)
        c:move_to_screen()
    end,
    {
        description = "move to screen",
        group = "client"
    }
),
-- awful.key(
--     {modkey},
--     "n",
--     function(c)
--         -- The client currently has the input focus, so it cannot be
--         -- minimized, since minimized clients can't have the focus.
--         c.minimized = true
--     end,
--     {
--         description = "minimize",
--         group = "client"
--     }
-- ),
-- -- all minimized clients are restored
-- awful.key(
--     {modkey, shiftkey},
--     "n",
--     function()
--         local tag = awful.tag.selected()
--         for i = 1, #tag:clients() do
--             tag:clients()[i].minimized = false
--             tag:clients()[i]:redraw()
--         end
--     end
-- ),

awful.key(
    {modkey, shiftkey},
    "a",
    function(c)
        awful.titlebar.toggle(c)
    end,
    {
        description = "Show title bar",
        group = "client"
    }
)
)

return clientkeys