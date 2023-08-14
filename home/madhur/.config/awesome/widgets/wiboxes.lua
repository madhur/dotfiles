local wibox = require("wibox")
local madhur = require("madhur")
local beautiful = require("beautiful")
local awful = require("awful")
local helpers = require("madhur.helpers")
local gears = require("gears")
local naughty = require("naughty")
local top_left = require("madhur.widget.top_left")
local wiboxes = {}

local widget_types = {}

-- generic function to apply background / forecolor on widget, the widget is expected to be wrapped in wibox.container.background, so that just bg and fg properties can be altered.
-- otherwise, each widget has its own way to set bg/ fg
local function styleWidget(background_container_widget, widget_type, background_color, foreground_color, normalize,
    warning_critical)

    -- normalize property is expected to be passed from when widgets is being changed from warning / critical signal to normal, so that it can restore back to default state
    if normalize then
        background_color = beautiful.darker
        foreground_color = beautiful.fg_normal
    end

    -- widget specific overrides, for default scenarios only.
    -- warning / critical styles are global for now
    if warning_critical == nil or warning_critical == false then
        if widget_type == "calendar" then
            background_color = "#11161b"
            -- foreground_color = "#94f7c5"
            foreground_color = "#85dfa8"
        elseif widget_type == "mem" then
            --foreground_color = "#8cc1ff"
            foreground_color = "#297639"
        elseif widget_type == "cpu_widget" or widget_type == "cpu_temp1" then
            --foreground_color = "#f46521"
            foreground_color = "#f06a2b"

        elseif widget_type == "cpufreq" then
            foreground_color = "#f06a2b"
        elseif widget_type == "temp" then
            foreground_color = "#f06a2b"

        elseif widget_type == "gpu" then
            foreground_color = "#94f7c5"

        elseif widget_type == "fs" then
            foreground_color = "#e2a6ff"
        elseif widget_type == "net_new" then
            foreground_color = "#90daff"
        elseif widget_type == "volume_new" then
            foreground_color = "#ffeba6"
        elseif widget_type == "uptime" then
            foreground_color = "#85dfa8"
        elseif widget_type == "pacman" then
            foreground_color = "#1793d1"
        end
    end

    -- we can change the bg / fg color in case of warning / critical if not passed from signal
    if warning_critical then
        foreground_color = beautiful.darker
    end
    -- if the properties are nil, the child widget will retain its background / foreground property. Useful when we dont want to override
    if background_color then
        background_container_widget.bg = background_color
    end

    if foreground_color then
        background_container_widget.fg = foreground_color
    end

end

local function pl(widget, reverse, widget_type)
    -- Uncomment below to have alternating background colors
    -- if reverse then
    --      color = beautiful.darker
    -- else
    --     color = beautiful.dark
    -- end

    -- Uncomment to enable powerline
    -- local finalWidget = wibox.container.background(wibox.container.margin(widget, 16, 16), background_color, powerline_rl)
    local finalWidget = wibox.container.background(wibox.container.margin(widget, 16, 16), nil, nil)
    styleWidget(finalWidget, widget_type, nil, nil, true)

    local tempWidget = wibox.widget {

        finalWidget,
        {
            id = "top_border",
            widget = wibox.widget.separator,
            forced_height = 2,
            thickness = 2,
            forced_width = 80,
            orientation = "horizontal",
            color = finalWidget.fg
        },
        layout = wibox.layout.fixed.vertical
    }

    -- Add margin if required
    --local fw = finalWidget
    local fw = wibox.container.margin(finalWidget, 10, 10, 0, 0)

    -- we do not pass fw to widget_types because signal manipulators manipulate bg / bg which are only available on background widget
    if widget_type then
        widget_types[widget_type] = finalWidget
    end
    return fw
end

awesome.connect_signal("warning", function(widget_type)
    -- helpers.debug(widget_type.."warning")
    styleWidget(widget_types[widget_type], widget_type, beautiful.warning_bg, nil, false, true)
    if awful.util.smart_wibar_hide then
        widget_types[widget_type].visible = true
    end
end)
awesome.connect_signal("critical", function(widget_type)
    -- helpers.debug(widget_type.."critical")
    styleWidget(widget_types[widget_type], widget_type, beautiful.critical_bg, nil, false, true)
    if awful.util.smart_wibar_hide then
        widget_types[widget_type].visible = true
    end
end)

awesome.connect_signal("normal", function(widget_type)
    -- helpers.debug(widget_type.."normal")
    if not widget_types[widget_type] then
        return
    end

    styleWidget(widget_types[widget_type], widget_type, nil, nil, true, false)

    if awful.util.smart_wibar_hide then
        widget_types[widget_type].visible = false
    else
        -- helpers.debug(widget_types["cpu"])
        widget_types[widget_type].visible = true
    end
end)

local cpu_temp =  wibox.widget {
    require("widgets.topbar.cpu"),
    require("widgets.helper").separator2,
    require("widgets.topbar.temp"),
    layout = wibox.layout.fixed.horizontal,
}

local right_widgets = {
    -- Right widgets
    layout = wibox.layout.fixed.horizontal,
    --pl (cpu_temp, true, "cpu_temp1"),
    pl((require("widgets.topbar.cpu")), true, "cpu_widget"),
    pl((require("widgets.topbar.temp")), false, "temp"),
    pl((require("widgets.topbar.memory")), true, "mem"),
    pl((require("widgets.topbar.disk")), true, "fs"),
    pl((require("widgets.topbar.network")), true, "net_new"),
    pl((require("widgets.topbar.uptime")), true, "uptime"),
    pl((require("widgets.topbar.volume")), "true", "volume_new"),
    pl((require("widgets.topbar.aws")), true, "aws"),
    --require("widgets.topbar.aws"),
    pl((require("widgets.topbar.pacman")), true, "pacman"),
    pl(top_left, true, ""),
    --pl((require("widgets.topbar.notification")), true, "notification"),
    wibox.container.margin((require("widgets.topbar.systray_new")), 3, 3, 3, 3)
}

local hr_spr = require("widgets.helper").hr_spr
local spr = require("widgets.helper").spr

function wiboxes.get(s)
    local mywibox = awful.wibar({
        position = "top",
        stretch = true,
        margins = 0,
        border_width = 0,
        screen = s,
        height = 30,
        bg = "#1a1b26aa",
        ontop = false
    })

    s.right_widgets = right_widgets
   
    local mylayoutbox = require("widgets.layoutbox").get(s)
    local mytaglist = require("widgets.taglist").get(s)
    local mytasklist = require("widgets.tasklist").get(s)
    local jgmenu = require("widgets.topbar.jgmenu")
    awful.util.mytasklist = mytasklist

    local left_widgets = {
        layout = wibox.layout.fixed.horizontal,
        wibox.container.margin((require("widgets.topbar.icon")), 5, 5, 5, 5),
        hr_spr,
        mytaglist,
        hr_spr,
        spr,
        wibox.container.margin(mylayoutbox, 5, 10, 5, 5),
        spr,
        mytasklist,
        jgmenu
    }

    mywibox:setup{
        layout = wibox.layout.align.horizontal,
        expand = "none",
        left_widgets,
        {
            layout = wibox.layout.align.horizontal,
            expand = "none",
            nil,
            pl(require("widgets.topbar.clock"), true, "calendar")
        },
        right_widgets
    }
    return mywibox
end

return wiboxes
