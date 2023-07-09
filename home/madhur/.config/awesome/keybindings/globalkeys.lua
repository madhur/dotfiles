local awful = require("awful")
local awesome, screen = awesome, screen
local client, root = client, root
local lain = require("lain")
local gears = require("gears")
local bling = require("bling")
local madhur = require("madhur")
local mymainmenu = require("widgets.menu")
local hotkeys_popup = require("awful.hotkeys_popup").widget
local naughty = require("naughty")
local logout_popup = require("awesome-wm-widgets.logout-popup-widget.logout-popup")
local mouse = require("awful.mouse")
local gfs = require("gears.filesystem")
local modkey = "Mod4"
local altkey = "Mod1"
local ctrlkey = "Control"
local shiftkey = "Shift"

local volume_id = {}
local show_volume_notification = function()
    local command =
        "sleep 0.09 ; pacmd list-sinks | grep -zo --color=never '* index:.*base volume' | grep -oaE '[0-9]+\\%' | awk -v RS= '{$1= $1}1'"
    awful.spawn.easy_async_with_shell(
        command,
        function(out)
            volume_id =
                naughty.notification {
                text = out,
                timeout = 1
            }
        end
    )
end

local globalkeys =
    gears.table.join( -- {{{ Personal keybindings
    awful.key(
        {altkey},
        "`",
        function()
            awful.util.magnifier = not awful.util.magnifier
            -- c:emit_signal(
            --     "request::activate",
            --     "titlebar",
            --     {
            --         raise = true
            --     }
            -- )
            awful.screen.focused().selected_tag:emit_signal("property::layout")
        end,
        {
            description = "enable magnifier",
            group = "awesome"
        }
    ),
    awful.key(
        {modkey, shiftkey},
        "r",
        awesome.restart,
        {
            description = "Reload awesome",
            group = "awesome"
        }
    ),
    awful.key(
        {modkey, shiftkey},
        "s",
        hotkeys_popup.show_help,
        {
            description = "Show help",
            group = "awesome"
        }
    ),
    awful.key(
        {modkey},
        "Escape",
        function()
            for s in screen do
                s.mywibox.visible = not s.mywibox.visible
            end
        end,
        {
            description = "Show/hide wibox (bar)",
            group = "awesome"
        }
    ),
    awful.key(
        {altkey},
        "Escape",
        function()
            for s in screen do
                --naughty.notify({text=tostring(s.mywibox.widget.third)})
                s.mywibox.widget.third.visible = not s.mywibox.widget.third.visible
            end
        end,
        {
            description = "Show/hide right wibox (bar)",
            group = "awesome"
        }
    ),
    awful.key(
        {ctrlkey},
        "Escape",
        function()
            awful.util.smart_wibar_hide = not awful.util.smart_wibar_hide
        end,
        {
            description = "Smart hide right wibox (bar)",
            group = "awesome"
        }
    ),
    awful.key(
        {modkey},
        "Tab",
        awful.tag.history.restore,
        {
            description = "go back",
            group = "tag"
        }
    ),
    -- Non-empty tag browsing CTRL+TAB (CTRL+SHIFT+TAB)
    awful.key(
        {altkey},
        "Left",
        function()
            lain.util.tag_view_nonempty(-1)
        end,
        {
            description = "view  previous nonempty",
            group = "tag"
        }
    ),
    awful.key(
        {altkey},
        "Right",
        function()
            lain.util.tag_view_nonempty(1)
        end,
        {
            description = "view  previous nonempty",
            group = "tag"
        }
    ),
    awful.key(
        {modkey},
        "Down",
        function()
            awful.client.focus.global_bydirection("down")
            if client.focus then
                client.focus:raise()
            end
        end,
        {
            description = "Focus down",
            group = "client"
        }
    ),
    awful.key(
        {modkey},
        "Up",
        function()
            awful.client.focus.global_bydirection("up")
            if client.focus then
                client.focus:raise()
            end
        end,
        {
            description = "Focus up",
            group = "client"
        }
    ),
    awful.key(
        {modkey},
        "Left",
        function()
            awful.client.focus.global_bydirection("left")
            if client.focus then
                client.focus:raise()
            end
        end,
        {
            description = "Focus left",
            group = "client"
        }
    ),
    awful.key(
        {modkey},
        "Right",
        function()
            awful.client.focus.global_bydirection("right")
            if client.focus then
                client.focus:raise()
            end
        end,
        {
            description = "Focus right",
            group = "client"
        }
    ),
    -- Layout manipulation
    awful.key(
        {modkey, shiftkey},
        "Left",
        function()
            awful.client.swap.byidx(1)
        end,
        {
            description = "swap with next client by index",
            group = "client"
        }
    ),
    awful.key(
        {modkey, shiftkey},
        "Right",
        function()
            awful.client.swap.byidx(-1)
        end,
        {
            description = "swap with previous client by index",
            group = "client"
        }
    ),
    awful.key(
        {modkey},
        "u",
        awful.client.urgent.jumpto,
        {
            description = "jump to urgent client",
            group = "client"
        }
    ),
    awful.key(
        {ctrlkey},
        "Tab",
        function()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end,
        {
            description = "go back",
            group = "client"
        }
    ),
    awful.key(
        {modkey},
        "l",
        function()
            awful.tag.incmwfact(0.05)
        end,
        {
            description = "increase master width factor",
            group = "layout"
        }
    ),
    awful.key(
        {modkey},
        "h",
        function()
            awful.tag.incmwfact(-0.05)
        end,
        {
            description = "decrease master width factor",
            group = "layout"
        }
    ),
    awful.key(
        {modkey, ctrlkey},
        "Up",
        function()
            awful.tag.incnmaster(1, nil, true)
        end,
        {
            description = "increase the number of master clients",
            group = "layout"
        }
    ),
    awful.key(
        {modkey, ctrlkey},
        "Down",
        function()
            awful.tag.incnmaster(-1, nil, true)
        end,
        {
            description = "decrease the number of master clients",
            group = "layout"
        }
    ),
    awful.key(
        {modkey, ctrlkey},
        "h",
        function()
            awful.tag.incncol(1, nil, true)
        end,
        {
            description = "increase the number of columns",
            group = "layout"
        }
    ),
    awful.key(
        {modkey, ctrlkey},
        "l",
        function()
            awful.tag.incncol(-1, nil, true)
        end,
        {
            description = "decrease the number of columns",
            group = "layout"
        }
    ),
    awful.key(
        {modkey},
        "space",
        function()
            awful.layout.inc(1)
        end,
        {
            description = "select next",
            group = "layout"
        }
    ),
    awful.key(
        {modkey},
        "w",
        function(_)
            awful.screen.focused().selected_tag.master_count = 0
            awful.layout.set(bling.layout.mstab)
        end,
        {
            description = "Switch to tab layout",
            group = "layout"
        }
    ),
    awful.key(
        {modkey},
        "e",
        function(_)
            awful.screen.focused().selected_tag.master_count = 1
            awful.layout.set(madhur.layout.tallmagnified)
        end,
        {
            description = "Switch to tall layout",
            group = "layout"
        }
    ),
    awful.key(
        {altkey},
        "Tab",
        function(_)
            awful.client.focus.byidx(1)
        end,
        {
            description = "cycle through clients",
            group = "layout"
        }
    ),
    -- awful.key(
    --     {modkey},
    --     "r",
    --     function(_)
    --         awful.util.myprompt:run()
    --     end,
    --     {
    --         description = "Run prompt",
    --         group = "wibar"
    --     }
    -- ),
    -- awful.key(
    --     {modkey},
    --     "r",
    --     function()
    --         awful.prompt.run(
    --             {
    --                 prompt       = "<b>Run: </b>",
    --                 textbox = awful.util.text_box_prompt,
    --                 history_path  = gfs.get_cache_dir() .. "/history",
    --                 exe_callback = function(...)
    --                     awful.spawn.easy_async(..., function(stdout, stderr, reason, exit_code)
    --                         local textbox = awful.util.text_box_prompt
    --                         if type(stdout) == "string" then
    --                             textbox:set_text(stdout)
    --                         end
    --                     end)
    --                 end
    --             }
    --         )
    --     end,
    --     {
    --         description = "Run command in prompt",
    --         group = "prompt"
    --     }
    -- ),
    awful.key(
        {modkey},
        "g",
        function(_)
            local s = awful.screen.focused()
            awful.util.expanded = not awful.util.expanded
            if awful.util.expanded then
                s.padding = {
                    left = 0,
                    right = 0,
                    top = 0,
                    bottom = 0
                }
            else
                s.padding = {
                    left = 0,
                    right = 500,
                    top = 0,
                    bottom = 0
                }
            end
            awful.screen.focused():emit_signal("property::layout")
        end,
        {
            description = "set gaps 500 px",
            group = "layout"
        }
    ),
    -- Dropdown application

    -- ALSA volume control
    awful.key(
        {},
        "XF86AudioRaiseVolume",
        function()
            awful.util.spawn("amixer -D pulse sset Master 5%+", false)
            -- show_volume_notification()
            awful.util.volume.update(nil, true)
            awful.util.volume_new:inc(5, true)
        end
    ),
    awful.key(
        {},
        "XF86AudioLowerVolume",
        function()
            awful.util.spawn("amixer -D pulse sset Master 5%-", false)
            -- show_volume_notification()
            awful.util.volume.update(nil, true)
            awful.util.volume_new:dec(5, true)
        end
    ),
    awful.key(
        {},
        "XF86AudioMute",
        function()
            awful.util.spawn("amixer -D pulse sset Master toggle", false)
            -- show_volume_notification()
            awful.util.volume.update(nil, true)
            awful.util.volume_new:toggle(true)
        end
    )
    -- awful.key(
    --     {modkey},
    --     "l",
    --     function()
    --         logout_popup.launch()
    --     end
    -- )
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it works on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 10 do
    -- Hack to only show tags 1 and 9 in the shortcut window (mod+s)
    local descr_view, descr_toggle, descr_move, descr_toggle_focus
    if i == 1 or i == 9 then
        descr_view = {
            description = "view tag #",
            group = "tag"
        }
        descr_toggle = {
            description = "toggle tag #",
            group = "tag"
        }
        descr_move = {
            description = "move focused client to tag #",
            group = "tag"
        }
        descr_toggle_focus = {
            description = "toggle focused client on tag #",
            group = "tag"
        }
    end
    globalkeys =
        gears.table.join(
        globalkeys, -- View tag only.
        awful.key(
            {modkey},
            "#" .. i + 9,
            function()
                local screen = awful.screen.focused()
                local tag = screen.tags[i]
                if tag then
                    tag:view_only()
                end
            end,
            descr_view
        ), -- Toggle tag display.
        awful.key(
            {modkey, ctrlkey},
            "#" .. i + 9,
            function()
                local screen = awful.screen.focused()
                local tag = screen.tags[i]
                if tag then
                    awful.tag.viewtoggle(tag)
                end
            end,
            descr_toggle
        ), -- Move client to tag.
        awful.key(
            {modkey, shiftkey},
            "#" .. i + 9,
            function()
                if client.focus then
                    local tag = client.focus.screen.tags[i]
                    if tag then
                        client.focus:move_to_tag(tag)
                    end
                end
            end,
            descr_move
        ), -- Toggle tag on focused client.
        awful.key(
            {modkey, ctrlkey, shiftkey},
            "#" .. i + 9,
            function()
                if client.focus then
                    local tag = client.focus.screen.tags[i]
                    if tag then
                        client.focus:toggle_tag(tag)
                    end
                end
            end,
            descr_toggle_focus
        )
    )
end

-- Set keys
root.keys(globalkeys)

root.buttons(
    gears.table.join(
        awful.button(
            {},
            3,
            function()
                mymainmenu:toggle()
            end
        ),
        awful.button({}, 4, awful.tag.viewnext),
        awful.button({}, 5, awful.tag.viewprev)
    )
)
