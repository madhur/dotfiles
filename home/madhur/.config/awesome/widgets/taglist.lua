local awful = require("awful")
local client = client
local gears = require("gears")

local modkey = "Mod4"

local taglist = {}

taglist.taglist_buttons =
    gears.table.join(
        
    awful.button(
        {},
        1,
        function(t)
            t:view_only()
        end
    ),
    awful.button(
        {modkey},
        1,
        function(t)
            if client.focus then
                client.focus:move_to_tag(t)
            end
        end
    ),
    awful.button({}, 3, awful.tag.viewtoggle),
    awful.button(
        {modkey},
        3,
        function(t)
            if client.focus then
                client.focus:toggle_tag(t)
            end
        end
    ),
    awful.button(
        {},
        4,
        function(t)
            awful.tag.viewnext(t.screen)
        end
    ),
    awful.button(
        {},
        5,
        function(t)
            awful.tag.viewprev(t.screen)
        end
    )
)

function taglist.get(s)
    local fancy_taglist = require("widgets.fancy_taglist")
    fancy_taglist =
        fancy_taglist.new(
        {
            screen = s,
            filter = function(t)
                return t.selected or #t:clients() > 0
            end,
            taglist_buttons = taglist.taglist_buttons,
            tasklist_buttons = require("widgets.tasklist").tasklist_buttons
        }
    )
    return fancy_taglist

end

return taglist