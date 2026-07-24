-- Hyprland Lua config (converted from hyprland.conf)
-- See https://wiki.hypr.land/Configuring/Start/

require("nvidia")


------------------
---- MONITORS ----
------------------

hl.monitor({
    output   = "DP-2",
    mode     = "3840x2160@60",
    position = "auto-left",
    scale    = 1.2,
})

-- Disable DP-1
hl.monitor({
    output   = "DP-1",
    disabled = true,
})


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = "thunar"
local menu        = "/home/madhur/scripts/launcher.sh"


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("dunst")
    hl.exec_cmd("indicator-sound-switcher")
    hl.exec_cmd("xettingsd")
    hl.exec_cmd("wlsunset -t 4500 -T 6500 -l 12.97 -L 77.59")
    hl.exec_cmd("/home/madhur/scripts/set_wallpaper_wayland.sh")
    hl.exec_cmd("hyprpm reload -n")
    hl.exec_cmd("wl-paste --watch cliphist store")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_THEME",   "Adwaita")
hl.env("XCURSOR_SIZE",    "36")
hl.env("HYPRCURSOR_SIZE", "36")


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in     = 3,
        gaps_out    = 0,
        border_size = 1,

        col = {
            active_border   = "rgba(4c7899ff)",
            inactive_border = "rgba(595959aa)",
        },

        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding           = 0,
        active_opacity     = 1.0,
        inactive_opacity   = 1.0,
        fullscreen_opacity = 1.0,

        blur = {
            enabled            = true,
            size               = 8,
            passes             = 3,
            vibrancy           = 0.1696,
            noise              = 0.0117,
            contrast           = 0.8916,
            brightness         = 0.8172,
            popups             = true,
            popups_ignorealpha = 0.2,
            new_optimizations  = true,
        },

        glow = {
            enabled        = true,
            range          = 10,
            render_power   = 3,
            color          = 0xcc4c7899,
            color_inactive = 0x004c7899,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },

    xwayland = {
        force_zero_scaling = true,
    },

    debug = {
        disable_logs = false,
    },
})

-- Animation curves
hl.curve("myBezier", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve("easy",     { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "windows",     enabled = true, speed = 1,    bezier = "myBezier" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 1,    bezier = "myBezier", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 1,    bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border",      enabled = true, speed = 1,    bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 1,    bezier = "default" })
hl.animation({ leaf = "fade",        enabled = true, speed = 1,    bezier = "default" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 1,    bezier = "default" })


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout    = "us",
        kb_variant   = "",
        kb_model     = "",
        kb_options   = "",
        kb_rules     = "",
        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers   = 4,
    direction = "horizontal",
    action    = "workspace",
})

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod  = "SUPER"
local altMod   = "ALT"
local ctrlMod  = "CTRL"
local shiftMod = "SHIFT"

-- Basic binds
hl.bind(mainMod .. " + Return",      hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q",           hl.dsp.window.close())
hl.bind(mainMod .. " + E",           hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + SHIFT + F",   hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + D",           hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + M",           hl.dsp.window.fullscreen({ mode = 1 }))
hl.bind(mainMod .. " + F",           hl.dsp.window.fullscreen({ mode = 0 }))
hl.bind(mainMod .. " + X",           hl.dsp.exec_cmd("/home/madhur/scripts/key-power"))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Swap windows with mainMod + SHIFT + arrow keys
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.swap({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.swap({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.swap({ direction = "down" }))

-- Switch workspaces with mainMod + [1-9]
-- Move active window to a workspace with mainMod + SHIFT + [1-9]
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i,           hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i,   hl.dsp.window.move({ workspace = i }))
end

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mod + LMB/RMB and drag
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Reload and misc
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind("mouse:274",         hl.dsp.window.close())

-- Waybar restart
hl.bind(mainMod .. " + SHIFT + W",
    hl.dsp.exec_cmd("killall waybar && waybar & && waybar -c ~/.config/waybar/vertical.jsonc &"))

-- Move window to next monitor
hl.bind(mainMod .. " + O", hl.dsp.window.move({ monitor = "+1" }))

-- Navigate previous/next non-empty workspace
hl.bind(altMod .. " + Left",  hl.dsp.focus({ workspace = "m-1" }))
hl.bind(altMod .. " + Right", hl.dsp.focus({ workspace = "m+1" }))

-- Quick-access terminal
hl.bind("SUPER + grave", hl.dsp.exec_cmd("kitten quick-access-terminal"))

-- Volume and screenshot
hl.bind("SUPER + F2",        hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("SUPER + F1",        hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("SUPER + F3",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind(mainMod .. " + SUPER + F12",
    hl.dsp.exec_cmd('grim -g "$(slurp -d)" - | wl-copy'))
-- NOTE: this duplicates SUPER + F2 above (intentional in original?); last bind wins
hl.bind("SUPER + F2",
    hl.dsp.exec_cmd("/usr/bin/rofi -modi clipboard:/home/madhur/scripts/cliphist-rofi-img -show clipboard -show-icons"))

-- Resize active window
hl.bind(mainMod .. " + L", hl.dsp.window.resize({ x = 50,  y = 0 }))
hl.bind(mainMod .. " + H", hl.dsp.window.resize({ x = -50, y = 0 }))

-- Cycle to next window
hl.bind(mainMod .. " + Space", hl.dsp.window.cycle_next())


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    name           = "suppress-maximize",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name      = "slack-workspace",
    match     = { class = "^(Slack)$" },
    workspace = "0",
})

-- Conky window rules (merged)
hl.window_rule({
    name        = "conky",
    match       = { class = "^(Conky)$" },
    float       = true,
    no_focus    = true,
    decorate    = false,
    border_size = 0,
    pin         = true,
    opacity     = 0.67,
})

-- Layer rules
hl.layer_rule({
    name  = "blur-waybar",
    match = { namespace = "waybar" },
    blur  = true,
})

hl.layer_rule({
    name  = "blur-rofi",
    match = { namespace = "rofi" },
    blur  = true,
})

