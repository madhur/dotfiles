local awful = require("awful")
local beautiful = require("beautiful")
local clientkeys = require("keybindings.clientkeys")
local mousekeys = require("keybindings.mousebindings")
-- Rules to apply to new clients (through the "manage" signal).
return {
    -- All clients will match this rule.
    {
        rule = {},
        properties = {
            border_width = beautiful.border_width,
            border_color = beautiful.border_normal,
            focus = awful.client.focus.filter,
            raise = true,
            keys = clientkeys,
            buttons = mousekeys,
            screen = awful.screen.preferred,
            placement = awful.placement.no_overlap + awful.placement.no_offscreen,
            size_hints_honor = false,
            maximized_vertical = false,
            maximized_horizontal = false
        }
    }, -- Titlebars
    {
        rule_any = {
            type = {"dialog", "normal"}
        },
        properties = {
            titlebars_enabled = false
        }
    },
    -- Set applications to always map on the tag 1 on screen 1.
    -- find class or role via xprop command
    -- {
    --     rule = {class = "Chrome"},
    --     properties = {screen = 1, tag = awful.screen.focused().tags[1]}
    -- },
    -- {
    --     rule = {class = "Google-chrome"},
    --     properties = {screen = 1, tag = awful.screen.focused().tags[1]}
    -- },
    {
        rule = {class = "jetbrains-idea-ce"},
        properties = {screen = 1, tag = awful.screen.focused().tags[2]}
    },
    {
        rule = {class = "Code"},
        properties = {screen = 1, tag = awful.screen.focused().tags[3]}
    },
    -- Set applications to always map on the tag 3 on screen 1.
    {
        rule = {class = "DBeaver"},
        properties = {screen = 1, tag = awful.screen.focused().tags[4]}
    },
    {
        rule = {class = "Postman"},
        properties = {screen = 1, tag = awful.screen.focused().tags[5]}
    },
    -- Set applications to always map on the tag 4 on screen 1.
    {
        rule = {class = "install4j-com-kafkatool-ui-MainApp"},
        properties = {screen = 1, tag = awful.screen.focused().tags[6]}
    },
    -- {
    --     rule = {class = "firefox"},
    --     properties = {screen = 1, tag = awful.screen.focused().tags[9]}
    -- },
    {
        rule = {class = "Slack"},
        properties = {screen = 1, tag = awful.screen.focused().tags[10]}
    },
    {
        rule = {class = "PanGPUI"},
        properties = {
            floating = true,
            titlebars_enabled = false
        },
        callback = function(c)
            awful.placement.top_right(c, nil)
        end
    },
    {
        rule_any = {
            class = {
                "kruler",
                "Kruler",
                "Guake"       
            },
        },
        properties = {
            floating = true,
            titlebars_enabled = false,
            placement = awful.placement.centered
        }
    },
    {
        rule_any = {
            class = {
                "copyq",
            },
        },
        properties = {
            floating = true,
            titlebars_enabled = false,
        },
        callback = function(c)
            local clnt = awful.client.focused
            awful.placement.centered(c, {parent =clnt})
        end
    },
    {
        rule_any = {
            instance = {
                "DTA", -- Firefox addon DownThemAll.
            },
            class = {
                "Arandr",
                "Blueberry",
                "Galculator",
                "Gnome-font-viewer",
                "Gpick",
                "Imagewriter",
                "Font-manager",
                "MessageWin",
                "Oblogout",
                "Peek",
                "Skype",
                "System-config-printer.py",
                "Sxiv",
                "Unetbootin.elf",
                "Wpa_gui",
                "pinentry",
                "veromix",
                "xtightvncviewer",
                "Gsimplecal",
                "Indicator-sound-switcher",
                "Pavucontrol",
                "pavucontrol"
            },
            name = {
                "Event Tester" -- xev.
            },
            role = {
                "AlarmWindow", -- Thunderbird's calendar.
                "pop-up", -- e.g. Google Chrome's (detached) Developer Tools.
                "Preferences",
                "setup"
            }
        },
        properties = {
            floating = true,
            titlebars_enabled = true,
            placement = awful.placement.centered
        }
    }
}
