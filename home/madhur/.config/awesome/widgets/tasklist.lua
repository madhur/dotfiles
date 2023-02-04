local awful = require("awful")
local madhur = require("madhur")
local wibox = require("wibox")
local gears = require("gears")
local client = client

local tasklist = {}

tasklist.tasklist_buttons =
    gears.table.join(
    awful.button(
        {},
        1,
        function(c)
            if c == client.focus then
                c.minimized = true
            else
                c:emit_signal(
                    "request::activate",
                    "tasklist",
                    {
                        raise = true
                    }
                )
            end
        end
    ),
    awful.button(
        {},
        3,
        function()
            local instance = nil

            return function()
                if instance and instance.wibox.visible then
                    instance:hide()
                    instance = nil
                else
                    instance =
                        awful.menu.clients(
                        {
                            theme = {
                                width = 250
                            }
                        }
                    )
                end
            end
        end
    ),
    awful.button(
        {},
        4,
        function()
            awful.client.focus.byidx(1)
        end
    ),
    awful.button(
        {},
        5,
        function()
            awful.client.focus.byidx(-1)
        end
    )
)

function tasklist.get(s)
    return madhur.widget.tasklist {
        screen = s,
        filter = awful.widget.tasklist.filter.currenttags,
        buttons = tasklist.tasklist_buttons ,
        style = {
            shape_border_width = 0,
            shape = gears.shape.rectangle
        },
        layout = {
            spacing = 20,
            layout = wibox.layout.fixed.horizontal,
            spacing_widget = {
                {
                    markup = "|",
                    widget = wibox.widget.textbox
                },
                valign = "center",
                halign = "center",
                widget = wibox.container.place
            }
        },
        -- Notice that there is *NO* wibox.wibox prefix, it is a template,
        -- not a widget instance.
        widget_template = {
            {
                {
                    {
                        id = "text_role",
                        widget = wibox.widget.textbox
                    },
                    layout = wibox.layout.fixed.horizontal
                },
                left = 10,
                right = 10,
                widget = wibox.container.margin
            },
            id = "background_role",
            widget = wibox.container.background,
        },
    }
end

return tasklist