local rnotification = require("ruled.notification")
local gears = require("gears")
local client = client
local theme_assets = require("beautiful.theme_assets")
local xresources = require("beautiful.xresources")
local dpi = xresources.apply_dpi
local theme = {}
local gfs = require("gears.filesystem")
local themes_path = gfs.get_themes_dir()
local naughty = require("naughty")

--------------------------
  -- NAUGHTY CONFIGURATION
  --------------------------
  naughty.config.defaults.ontop = true
  naughty.config.defaults.icon_size = dpi(32)
  naughty.config.defaults.timeout = 10
  naughty.config.defaults.hover_timeout = 300
  --naughty.config.defaults.title = 'System Notification Title'
  naughty.config.defaults.margin = dpi(16)
  naughty.config.defaults.border_width = 1
  naughty.config.defaults.position = 'top_right'
  -- naughty.config.defaults.shape = function(cr, w, h)
  --   gears.shape.rounded_rect(cr, w, h, dpi(6))
  -- end

theme.tabbed_spawn_in_tab = false -- whether a new client should spawn into the focused tabbing container

theme.dark = "#2b2f40"
theme.darker = "#1a1b26"
-- mstab

theme.mstab_bar_ontop = false -- whether you want to allow the bar to be ontop of clients
theme.mstab_dont_resize_slaves = false -- whether the tabbed stack windows should be smaller than the
-- currently focused stack window (set it to true if you use
-- transparent terminals. False if you use shadows on solid ones
theme.mstab_bar_padding = "default" -- how much padding there should be between clients and your tabbar
-- by default it will adjust based on your useless gaps.
-- If you want a custom value. Set it to the number of pixels (int)
theme.mstab_border_radius = 0 -- border radius of the tabbar
theme.tabbar_size = 25 -- height of the tabbar
theme.mstab_tabbar_position = "top" -- position of the tabbar (mstab currently does not support left,right)
theme.tabbar_bg_normal = "#5f676a"
theme.tabbar_fg_normal = "#ffffff"
theme.tabbar_bg_focus = "#285577"
theme.tabbar_fg_focus = "#ffffff"
theme.tabbar_bg_focus_inactive = "#5f676a"
theme.tabbar_fg_focus_inactive = "#ffffff"
theme.tabbar_bg_normal_inactive = "#5f676a"
theme.tabbar_fg_normal_inactive = "#ffffff"
theme.tabbar_font = "DejaVu Sans Mono 12"
-- theme.wallpaper                                 = theme.dir .. "/starwars.jpg"
theme.font = "JetBrains Mono Nerd Font 11"
theme.hotkeys_description_font  = "JetBrains Mono Nerd Font 14"
theme.systray_icon_spacing = 4
theme.gap_single_client = false
theme.taglist_font = "DejaVu Sans Mono 11"
--theme.taglist_font = "JetBrains Mono Nerd Font 11"

theme.tasklist_font = "UbuntuMono Nerd Font 11"
theme.fg_normal = "#81a1c1"
theme.fg_focus = "#1a1b26"
theme.fg_urgent = "#b74822"
theme.bg_normal = "#1a1b26"
theme.bg_focus = "#81a1c1"
theme.bg_urgent = "#3F3F3F"
--theme.taglist_fg_focus = "#f0f0f0"
--theme.taglist_bg_focus = "#5e81ac"
theme.taglist_bg_focus = "00"
theme.taglist_fg_focus = "#81a1c1"
--theme.taglist_bg_focus = "#2e3440"
--theme.taglist_shape_border_width_focus = 2
theme.taglist_shape_border_color_focus = "#81a1c1"
--theme.taglist_shape_focus = 

-- Generate taglist squares:

--theme.taglist_bg_occupied = "#1a1b26"
--theme.taglist_bg_occupied = "00"
theme.taglist_fg_occupied = "#81a1c1"
theme.taglist_spacing = 3
--theme.tasklist_bg_focus = "#2b2f40"
theme.tasklist_bg_normal = "00"
theme.tasklist_bg_focus = "#2b2f40"
theme.tasklist_fg_focus = "#81a1c1"
theme.border_width = 1
theme.border_normal = "#333333"
-- theme.border_normal = "#00ff00"
theme.border_focus = "#4c7899"
theme.border_marked = "#CC9393"
theme.titlebar_bg_focus = "#3F3F3F"
theme.titlebar_bg_normal = "#3F3F3F"
theme.titlebar_bg_focus = theme.bg_focus
theme.titlebar_bg_normal = theme.bg_normal
theme.titlebar_fg_focus = theme.fg_focus
theme.menu_height = 30
theme.menu_width = 200
-- Generate Awesome icon:
theme.awesome_icon = theme_assets.awesome_icon(
    20, theme.bg_focus, theme.fg_focus
)
theme.tasklist_plain_task_name = false
theme.tasklist_disable_icon = true

theme.titlebar_fg_normal = theme.fg_normal
theme.titlebar_bg_normal = theme.darker

theme.titlebar_fg = theme.fg_normal
theme.titlebar_bg = theme.darker

theme.titlebar_fg_focus = theme.fg_normal
theme.titlebar_bg_focus = theme.dark

theme.titlebar_bgimage = function(context, cr, width, height)
         local pattern = gears.color(theme.titlebar_bg_normal)
         if client.focus == context.client then
             pattern = gears.color({ type = "linear",
                                     from = { 0, 0 },
                                     to = { width, 0 },
                                     stops = { { 0, theme.titlebar_bg_normal },
                                               { 0.35, theme.titlebar_bg_focus },
                                               { 0.65, theme.titlebar_bg_focus },
                                              { 1, theme.titlebar_bg_normal },
                                            },
                                  })
        end
        cr:set_source(pattern)
        cr:paint()
    end



-- Define the image to load
theme.titlebar_close_button_normal = themes_path.."default/titlebar/close_normal.png"
theme.titlebar_close_button_focus  = themes_path.."default/titlebar/close_focus.png"

theme.titlebar_minimize_button_normal = themes_path.."default/titlebar/minimize_normal.png"
theme.titlebar_minimize_button_focus  = themes_path.."default/titlebar/minimize_focus.png"

theme.titlebar_ontop_button_normal_inactive = themes_path.."default/titlebar/ontop_normal_inactive.png"
theme.titlebar_ontop_button_focus_inactive  = themes_path.."default/titlebar/ontop_focus_inactive.png"
theme.titlebar_ontop_button_normal_active = themes_path.."default/titlebar/ontop_normal_active.png"
theme.titlebar_ontop_button_focus_active  = themes_path.."default/titlebar/ontop_focus_active.png"

theme.titlebar_sticky_button_normal_inactive = themes_path.."default/titlebar/sticky_normal_inactive.png"
theme.titlebar_sticky_button_focus_inactive  = themes_path.."default/titlebar/sticky_focus_inactive.png"
theme.titlebar_sticky_button_normal_active = themes_path.."default/titlebar/sticky_normal_active.png"
theme.titlebar_sticky_button_focus_active  = themes_path.."default/titlebar/sticky_focus_active.png"

theme.titlebar_floating_button_normal_inactive = themes_path.."default/titlebar/floating_normal_inactive.png"
theme.titlebar_floating_button_focus_inactive  = themes_path.."default/titlebar/floating_focus_inactive.png"
theme.titlebar_floating_button_normal_active = themes_path.."default/titlebar/floating_normal_active.png"
theme.titlebar_floating_button_focus_active  = themes_path.."default/titlebar/floating_focus_active.png"

theme.titlebar_maximized_button_normal_inactive = themes_path.."default/titlebar/maximized_normal_inactive.png"
theme.titlebar_maximized_button_focus_inactive  = themes_path.."default/titlebar/maximized_focus_inactive.png"
theme.titlebar_maximized_button_normal_active = themes_path.."default/titlebar/maximized_normal_active.png"
theme.titlebar_maximized_button_focus_active  = themes_path.."default/titlebar/maximized_focus_active.png"

theme.useless_gap = 0
theme.gap_single_client = false
theme.notification_opacity = 100
theme.notification_icon_size = 80
theme.notification_bg = "#1a1b26"
theme.notification_fg = "#81a1c1"
theme.notification_border_width = 0

theme.layoutbox_font = "UbuntuMono Nerd Font 11"
theme.taglist_border_color = "#8be9fd"

theme.warning_bg = "#ebcb8b"
theme.warning_fg = "#2e3440"
theme.critical_bg = "#bf616a"
theme.critical_fg = "#2e3440"

theme.hotkeys_font = "JetBrains Mono Nerd Font 12"
theme.hotkeys_description_font = "JetBrains Mono Nerd Font 12"

-- Set different colors for urgent notifications.
rnotification.connect_signal('request::rules', function()
    rnotification.append_rule {
        rule       = { urgency = 'critical' },
        properties = { bg = '#ff0000', fg = '#ffffff' }
    }
end)


return theme
