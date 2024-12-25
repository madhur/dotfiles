import os
import subprocess

from libqtile import hook, layout, bar
from libqtile.config import EzKey as Key, EzClick as Click, EzDrag as Drag, Group, Match, Screen
from libqtile.lazy import lazy

from qtile_extras import widget
from qtile_extras.widget.decorations import BorderDecoration, RectDecoration, PowerLineDecoration

from modules._volume import Volume

from dataclasses import dataclass

# Start flavours
@dataclass(frozen=True)
class Colors:
    transparent=  '#00000000'
    background=   '#1b1b1b'
    foreground=   '#d4be98'

    black     = '#282828'
    red       = '#ea6962'
    green     = '#a9b665'
    yellow    = '#d8a657'
    blue      = '#7daea3'
    magenta   = '#d3869b'
    cyan      = '#89b482'
    white     = '#ddc7a1'
    gray      = '#32302f'
    graylight = '#45403d'
    
palette = Colors()
# End flavours

@dataclass(frozen=True)
class Preferences:
    terminal            =   "kitty"
    browser             =   "brave"
    private             =   "brave --private-window"
    file_manager        =   "thunar"
    screenshot_tool     =   'flameshot gui'
    code_editor         =   "micro"
    launcher            =   "rofi -show drun"
    power_menu          =   os.path.expanduser('~/.local/bin/powermenu.sh')
    font                =   'JetBrainsMono NF'
    corner              =   0

prefs = Preferences()

def rectdeco(hexcolor,corner=None): #kesekki iwa
	return RectDecoration(
		filled=True, colour=hexcolor,padding=5,
		radius=corner if corner is not None else 0)	

widget_list=[  
    widget.TextBox(
        text="  󰣇   ",
        foreground=palette.blue, 
        font=prefs.font, fontsize=18,
        mouse_callbacks={"Button1": lambda: qtile.cmd_spawn(prefs.launcher)},
        margin=7, decorations=[rectdeco(palette.graylight,prefs.corner)]
    ),
    widget.GroupBox(  
        this_current_screen_border=palette.blue, 
        active=palette.yellow, 
        inactive=palette.background,
        highlight_method='text', 
        borderwidth=0, margin_x=11, padding=0,
        font=prefs.font, fontsize=18,
        decorations=[rectdeco(palette.graylight,prefs.corner)],
    ),
    widget.Spacer(),
    Volume(
        foreground=palette.black,
        padding=12,marfin=7,
        font=prefs.font, fontsize=14,
        decorations=[rectdeco(palette.yellow,prefs.corner)],
	),
	widget.Clock(  
        foreground=palette.black, 
        format="   󱨴 %a, %d %b   ",        
        font=prefs.font, fontsize=14,
        decorations=[rectdeco(palette.green,prefs.corner)],
    ),
    widget.Clock(  
        foreground=palette.black, 
        format="   󱦟 %I:%M   ",        
        font=prefs.font, fontsize=14,
        decorations=[rectdeco(palette.blue,prefs.corner)],
    ),
    widget.WidgetBox(
        fmt= '   {} ⠀  ', 
        foreground=palette.black, 
        text_closed='', text_open='', 
        close_button_location='right',
        widgets=[widget.Systray()], 
        font=prefs.font, fontsize=12,
        decorations=[rectdeco(palette.red,prefs.corner)],
    ), 
]

def group(group_labels):
    group = []
    group_names = ["1", "2", "3", "4", "5"]
    for i in range(len(group_names)):
        group.append(Group(name=group_names[i], label=group_labels[i]))
    return group

groups = group([" १ ", " २ ", " ३ ", " ४ ", " ५ "])


def init_layout_theme():
    return {
        "border_width"      :   1,
        "margin"            :   10,
        "border_focus"      :   [palette.background],
        "border_normal"     :   [palette.background],
        "grow_amount"       :   5,
        "num_columns"       :   3, 
    }

def init_float_theme():
    return {
        'float_rules'       :   [
                                    *layout.Floating.default_float_rules,
                                    Match(wm_class="Pavucontrol"),  
                                    Match(wm_class="Nitrogen"),
                                    Match(wm_class="Lxappearance"),
                                ], 
        **init_layout_theme()
    }

layouts = [
    layout.Columns(**init_layout_theme()),
    layout.Floating(**init_layout_theme()),
]

floating_layout = layout.Floating(**init_float_theme())

def window_to_next_screen(qtile, switch_group=False, switch_screen=False):
    i = qtile.screens.index(qtile.current_screen)
    if i + 1 != len(qtile.screens):
        group = qtile.screens[i + 1].group.name
        qtile.current_window.togroup(group, switch_group=switch_group)
        if switch_screen == True:
            qtile.cmd_to_screen(i + 1)


keys = [
    # Switch between windows
    Key('M-<Left>',                 lazy.layout.left(),                             desc='Move focus to left'),
    Key('M-<Right>',                lazy.layout.right(),                            desc='Move focus to right'),
    Key('M-<Up>',                   lazy.layout.up(),                               desc='Move focus to up'),
    Key('M-<Down>',                 lazy.layout.down(),                             desc='Move focus to down'),
    Key('M-<Space>',                lazy.layout.next(),                             desc='Move window focus to other window'),

    #Move windows between left/right columns or move up/down in current stack.
    Key('M-S-<Left>',               lazy.layout.shuffle_left(),                     desc='Move window to left'),
    Key('M-S-<Right>',              lazy.layout.shuffle_right(),                    desc='Move window to right'),
    Key('M-S-<Up>',                 lazy.layout.shuffle_up(),                       desc='Move window to up'),
    Key('M-S-<Down>',               lazy.layout.shuffle_down(),                     desc='Move window to down'),
    
    # Grow windows.
    Key('M-h',               lazy.layout.grow_left(),                        desc='Grow window to left'),
    Key('M-l',              lazy.layout.grow_right(),                       desc='Grow window to right'),
    Key('M-j',                 lazy.layout.grow_up(),                          desc='Grow window to up'),
    Key('M-k',               lazy.layout.grow_down(),                        desc='Grow window to down'),
#    Key('M-n',                      lazy.layout.normalize(),                        desc='Reset all window sizes'),

    # Toggle between different layouts 
    #Key('M-<Tab>',                  lazy.next_layout(),                             desc='Toggle between layouts'),

    # More Window Stuff
    Key('M-f',                      lazy.window.toggle_fullscreen(),                  desc='Toggle floating window'),
    Key('M-m',                      lazy.window.toggle_maximize(),                  desc='Toggle floating window'),

#   Key('M-o', window_to_next_screen(qtile), desc='Move window to another screen'),

    # Base Qtile
    Key('M-S-r',                    lazy.restart(),                                 desc='Restart Qtile'),
  #  Key('M-S-q',                    lazy.shutdown(),                                desc='Shutdown Qtile'),
#    Key('M-x',                      lazy.window.kill(),                             desc='Kill focused window')

    #Rofi
#    Key('M-d',                      lazy.spawn(prefs.launcher),                     desc='Launch Menu'),
#    Key('M-q',                      lazy.spawn(prefs.power_menu),                   desc='Launch Power Menu'),
#    Key('M-<Return>',               lazy.spawn(prefs.terminal),                     desc='Launch Terminal'),

    # Launch Applications
#    Key('M-C-b',                    lazy.spawn(prefs.browser),                      desc='Launch Browser'),
#    Key('M-C-p',                    lazy.spawn(prefs.private),                      desc='Launch Incognito Browser'),
#    Key('M-C-e',                    lazy.spawn(prefs.code_editor),                  desc='Launch Editor'),
#    Key('M-C-f',                    lazy.spawn(prefs.file_manager),                 desc='Launch File Manager'),
#    Key('M-C-v',                    lazy.spawn('pavucontrol'),                      desc='Launch Volume Control'),
        
    # Take Screenshotpp
 #   Key('<Print>',                  lazy.spawn(prefs.screenshot_tool),              desc='Take a Screenshot'),
    
    # Media hotkeys
#    Key('<XF86AudioRaiseVolume>',   lazy.spawn('pactl set-sink-volume 0 +5%'),      desc='Raise Volume'),
#    Key('<XF86AudioLowerVolume>',   lazy.spawn('pactl set-sink-volume 0 -5%'),      desc='Lower Volume'),
#    Key('<XF86AudioMute>',          lazy.spawn('pactl set-sink-mute 0 toggle'),     desc='Mute Volume'),
#    Key('<XF86AudioPlay>',          lazy.spawn('playerctl play-pause'),             desc='Play / Pause Media'),
#    Key('<XF86AudioNext>',          lazy.spawn('playerctl next'),                   desc='Play Next'),
#    Key('<XF86AudioPrev>',          lazy.spawn('playerctl previous'),               desc='Play Previous'),

    # Brigtness
 #   Key('<XF86MonBrightnessUp>',    lazy.spawn('brightnessctl s 10+'),              desc='Increase Brightness'),
 #   Key('<XF86MonBrightnessDown>',  lazy.spawn('brightnessctl s 10-'),              desc='Decrease Brightness'), 
]

for i in groups:
    keys.extend(
        [
            Key('M-'+i.name,        lazy.group[i.name].toscreen(),                  desc='Switch to group {}'.format(i.name)),
            Key('M-S-'+i.name,      lazy.window.togroup(i.name, switch_group=False),desc='Move focused window to group {}'.format(i.name)),
        ]
    )

mouse = [
    Drag("M-1", lazy.window.set_position_floating(), start=lazy.window.get_position()),
    Drag("M-3", lazy.window.set_size_floating(), start=lazy.window.get_size()),
    Click("M-2", lazy.window.bring_to_front())
]

screens = [
    Screen(       
        top=bar.Bar(
            widget_list,
            size=35, opacity=1,
            border_width=[0,0,0,0], #N E S W
            background=palette.background, 
        ),
    ),
]

dgroups_key_binder = None
dgroups_app_rules = [] 
follow_mouse_focus = True
bring_front_click = False
cursor_warp = True
auto_fullscreen = True
focus_on_window_activation = "smart"
reconfigure_screens = False
auto_minimize = True

wmname = "LG3D"

@hook.subscribe.startup_once
def autostart():
    home = os.path.expanduser('~/scripts/autostart_qtile.sh')
    subprocess.call([home])
