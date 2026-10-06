--[[

        Licensed under GNU General Public License v2
        * (c) 2021, bzgec


# Microphone state widget/watcher

This widget can be used to display the current microphone status.

## Requirements

- `amixer` - this command is used to get and toggle microphone state

## Usage

- Download [mic.lua](https://awesomewm.org/recipes/mic.lua) file and put it into awesome's
  folder (like `~/.config/awesome/widgets/mic.lua`)

- Add widget to `theme.lua`:

```lua
local widgets = {
    mic = require("widgets/mic"),
}
theme.mic = widgets.mic({
    timeout = 10,
    settings = function(self)
        if self.state == "muted" then
            self.widget:set_image(theme.widget_micMuted)
        else
            self.widget:set_image(theme.widget_micUnmuted)
        end
    end
})
local widget_mic = wibox.widget { theme.mic.widget, layout = wibox.layout.align.horizontal }
```

- Create a shortcut to toggle microphone state (add to `rc.lua`):

```lua
-- Toggle microphone state
awful.key({ modkey, "Shift" }, "m",
          function ()
              beautiful.mic:toggle()
          end,
          {description = "Toggle microphone (amixer)", group = "Hotkeys"}
),
```

- You can also add a command to mute the microphone state on boot. Add this to your `rc.lua`:

```lua
-- Mute microphone on boot
beautiful.mic:mute()
```

--]]


local awful   = require("awful")
local naughty = require("naughty")
local gears   = require("gears")
local wibox   = require("wibox")

local function factory(args)
    local args = args or {}

    local mic = {
        widget   = args.widget or wibox.widget.imagebox(),
        settings = args.settings or function(self) end,
        timeout  = args.timeout or 10,
        timer    = gears.timer,
        state    = "",
    }

    function mic:mute()
        awful.spawn.easy_async({"amixer", "set", "Capture", "nocap"},
            function()
                self:update()
            end
        )
    end

    function mic:unmute()
        awful.spawn.easy_async({"amixer", "set", "Capture", "cap"},
            function()
                self:update()
            end
        )
    end

    function mic:toggle()
        awful.spawn.easy_async({"amixer", "set", "Capture", "toggle"},
            function()
                self:update()
            end
        )
    end

    function mic:pressed(button)
        if button == 1 then
            self:toggle()
        end
    end

    function mic:update()
        -- Check that timer has started
        if self.timer.started then
            self.timer:emit_signal("timeout")
        end
    end

    -- Read `amixer get Capture` command and try to `grep` all "[on]" lines.
    --   - If there are lines with "[on]" then assume microphone is "unmuted".
    --   - If there are NO lines with "[on]" then assume microphone is "muted".
    mic, mic.timer = awful.widget.watch(
        {"bash", "-c", "amixer get Capture | grep '\\[on\\]'"},
        mic.timeout,
        function(self, stdout, stderr, exitreason, exitcode)
            local current_micState = "error"

            if exitcode == 1 then
                -- Exit code 1 - no line selected
                current_micState = "muted"
            elseif exitcode == 0 then
                -- Exit code 0 - a line is selected
                current_micState = "unmuted"
            else
                -- Other exit code (2) - error occurred
                current_micState = "error"
            end

            -- Compare new and old state
            if current_micState ~= self.state then
                if current_micState == "muted" then
                    naughty.notify({preset=naughty.config.presets.normal,
                                    title="mic widget info",
                                    text='muted'})
                elseif current_micState == "unmuted" then
                    naughty.notify({preset=naughty.config.presets.normal,
                                    title="mic widget info",
                                    text='unmuted'})
                else
                    naughty.notify({preset=naughty.config.presets.critical,
                                    title="mic widget error",
                                    text='Error on "amixer get Capture | grep \'\\[on\\]\'"'})
                end

                -- Store new microphone state
                self.state = current_micState
            end

            -- Call user/theme defined function
            self:settings()
        end,
        mic  -- base_widget (passed in callback function as first parameter)
    )

    -- add mouse click
    mic.widget:connect_signal("button::press", function(c, _, _, button)
        mic:pressed(button)
    end)

    return mic
end

return factory
