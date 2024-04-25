--[[
     Licensed under GNU General Public License v2
      * (c) 2013, Luca CPZ
      * (c) 2022, tronfy <https://github.com/tronfy>
--]]

local wibox    = require("wibox")
local spawn = require("awful.spawn")
local timer  = require("gears.timer")
local naughty = require("naughty")
local awful = require("awful")
local notif_center = require("popups.notif_center.main")

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

    local notification   = { widget = args.widget or wibox.widget.textbox() }
    local timeout  = args.timeout or 10
    local settings = args.settings or function() end

    function notification.update()
        widget = notification.widget
        if naughty.suspended then
            result = "  "
        else
            result = "  "
        end
        if naughty.expiration_paused then
            result = result .. ""
        end
        --awesome.emit_signal("normal", "notification")
        settings()
    end


    notification.widget:buttons(
    awful.util.table.join(
        awful.button(
            {},
            1,
            function()
               -- naughty.suspended = not naughty.suspended
               -- notification.update()
               notif_center.visible = not notif_center.visible
            end
        ),
        awful.button(
            {},
            2,
            function()
                -- right click
                local list = naughty.active
                if #list > 0 then
                    for notify_obj = 1,#list do
                        naughty.notify({text=list[notify_obj].text})
                    end
                end
            end
        ),
        awful.button(
            {},
            3,
            function()
                -- right click

                naughty.suspended = not naughty.suspended
                notification.update()
                --naughty.expiration_paused = not naughty.expiration_paused
                --notification.update()
            end
        )
    )
)

    newtimer("notfication", timeout, notification.update)
    return notification
end

return factory