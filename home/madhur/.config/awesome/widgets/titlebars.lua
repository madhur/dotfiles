-- Add a titlebar if titlebars_enabled is set to true in the rules.
local beautiful = require("beautiful")
local client = client
local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")

client.connect_signal(
    "request::titlebars",
    function(c)
        -- Custom
        if beautiful.titlebar_fun then
            beautiful.titlebar_fun(c)
            return
        end

        -- Default
        -- buttons for the titlebar
        local buttons =
            gears.table.join(
            awful.button(
                {},
                1,
                function()
                    c:emit_signal(
                        "request::activate",
                        "titlebar",
                        {
                            raise = true
                        }
                    )
                    awful.mouse.client.move(c)
                end
            ),
            awful.button(
                {},
                3,
                function()
                    c:emit_signal(
                        "request::activate",
                        "titlebar",
                        {
                            raise = true
                        }
                    )
                    awful.mouse.client.resize(c)
                end
            )
        )

        awful.titlebar(
            c,
            {
                size = 30
            }
        ):setup {
            expand = "none",
            layout = wibox.layout.align.horizontal,
            
            {
                buttons = buttons,
                widget = wibox.widget.textbox
            },
            {
                layout = wibox.layout.fixed.horizontal,
                awful.titlebar.widget.iconwidget(c),
                {
                    markup = " ",
                    widget = wibox.widget.textbox
                },
                awful.titlebar.widget.titlewidget(c),
                buttons = buttons
            },
            {
                -- Right
                awful.titlebar.widget.floatingbutton(c),
                awful.titlebar.widget.minimizebutton(c),
                awful.titlebar.widget.maximizedbutton(c),
                --awful.titlebar.widget.stickybutton(c),
                --awful.titlebar.widget.ontopbutton(c),
                awful.titlebar.widget.closebutton(c),
                layout = wibox.layout.fixed.horizontal()
            }
        }
    end
)
