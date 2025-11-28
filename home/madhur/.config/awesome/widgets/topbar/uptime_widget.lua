-- Uptime Tracker Widget for AwesomeWM
-- Displays terminal output from uptime_tracker.py
-- Click on wibar icon to toggle display

local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local naughty = require("naughty")

local uptime_widget = {}

-- Configuration
local config = {
    script_path = os.getenv("HOME") .. "/.config/conky/uptime_tracker.py",
    update_interval = 300, -- 5 minutes
    weeks = 20, -- Number of weeks to display
    popup_width = 900,
    popup_height = 500,
    show_dates = true, -- Set to false to hide dates
}

-- Color scheme
local colors = {
    background = "#0d1117",
    text = "#c9d1d9",
    border = "#30363d",
}

-- Create the widget icon for wibar
local widget_icon = wibox.widget {
    markup = '<span foreground="#39d353">󰄉</span>', -- Calendar icon
    font = "Nerd Font 14",
    align = "center",
    valign = "center",
    widget = wibox.widget.textbox,
}

-- Create tooltip for the icon
local icon_tooltip = awful.tooltip {
    objects = { widget_icon },
    text = "System Uptime Tracker\nClick to view graph",
    timer_function = function()
        return "System Uptime Tracker\nClick to view graph"
    end,
}

-- Create the popup widget
local function create_popup_widget()
    local popup_widget = wibox.widget {
        {
            {
                markup = '<span font="14" foreground="' .. colors.text .. '">System Uptime Tracker</span>',
                align = "center",
                widget = wibox.widget.textbox,
            },
            top = 10,
            bottom = 10,
            widget = wibox.container.margin,
        },
        {
            id = "graph_container",
            markup = '<span foreground="' .. colors.text .. '">Loading...</span>',
            font = "monospace 10",
            widget = wibox.widget.textbox,
        },
        layout = wibox.layout.fixed.vertical,
    }

    return popup_widget
end

-- ANSI to Pango color mapping
local ansi_colors = {
    -- Foreground colors (38;5;N)
    ["38;5;255"] = "#ffffff",  -- White text
    ["38;5;240"] = "#585858",  -- Dark gray text
    ["38;5;250"] = "#bcbcbc",  -- Light gray text
    ["38;5;232"] = "#080808",  -- Very dark text

    -- Background colors (48;2;R;G;B) - RGB format matching GitHub/Conky
    ["48;2;33;38;45"] = "#21262d",     -- Dark gray background (no activity)
    ["48;2;14;68;41"] = "#0e4429",     -- Dark green background (low activity)
    ["48;2;0;109;50"] = "#006d32",     -- Medium green background
    ["48;2;38;166;65"] = "#26a641",    -- Bright green background
    ["48;2;57;211;83"] = "#39d353",    -- Brightest green background (high activity)
}

-- Convert ANSI codes to Pango markup
local function ansi_to_pango(text)
    -- First, escape XML
    text = text:gsub('&', '&amp;')
    text = text:gsub('<', '&lt;')
    text = text:gsub('>', '&gt;')

    -- Replace specific ANSI patterns with Pango spans
    -- Pattern: background color followed by foreground color followed by text followed by reset
    -- \033[48;2;R;G;Bm\033[38;5;Nm...\033[0m

    for bg_code, bg_color in pairs(ansi_colors) do
        if bg_code:match('^48;2') or bg_code:match('^48;5') then
            -- Escape special pattern characters (semicolon is not special in Lua patterns)
            local escaped_code = bg_code:gsub('%-', '%%-')
            text = text:gsub('\027%[' .. escaped_code .. 'm', '<BG' .. bg_code:gsub(';', '_') .. '>')
        end
    end

    for fg_code, fg_color in pairs(ansi_colors) do
        if fg_code:match('^38;5') then
            local escaped_code = fg_code:gsub('%-', '%%-')
            text = text:gsub('\027%[' .. escaped_code .. 'm', '<FG' .. fg_code:gsub(';', '_') .. '>')
        end
    end

    -- Replace reset
    text = text:gsub('\027%[0m', '<RESET>')
    -- Replace bold
    text = text:gsub('\027%[1m', '<BOLD>')
    -- Replace dim
    text = text:gsub('\027%[2m', '')

    -- Now convert our placeholders to actual Pango
    -- Pattern: <BGxx><FGxx>text<RESET> or <BGxx><FGxx><BOLD>text<RESET> or <BGxx>text<RESET>

    -- Handle background + foreground + bold + content
    text = text:gsub('<BG([^>]+)><FG([^>]+)><BOLD>([^<]*)<RESET>', function(bg, fg, content)
        bg = bg:gsub('_', ';')
        fg = fg:gsub('_', ';')
        local bg_color = ansi_colors[bg] or ''
        local fg_color = ansi_colors[fg] or ''
        return '<span background="' .. bg_color .. '" foreground="' .. fg_color .. '" weight="bold">' .. content .. '</span>'
    end)

    -- Handle background + foreground + content
    text = text:gsub('<BG([^>]+)><FG([^>]+)>([^<]*)<RESET>', function(bg, fg, content)
        bg = bg:gsub('_', ';')
        fg = fg:gsub('_', ';')
        local bg_color = ansi_colors[bg] or ''
        local fg_color = ansi_colors[fg] or ''
        return '<span background="' .. bg_color .. '" foreground="' .. fg_color .. '">' .. content .. '</span>'
    end)

    -- Handle background only + bold + content (for boxes without text color)
    text = text:gsub('<BG([^>]+)><BOLD>([^<]*)<RESET>', function(bg, content)
        bg = bg:gsub('_', ';')
        local bg_color = ansi_colors[bg] or ''
        return '<span background="' .. bg_color .. '" weight="bold">' .. content .. '</span>'
    end)

    -- Handle background only + content (for boxes without text color)
    text = text:gsub('<BG([^>]+)>([^<]*)<RESET>', function(bg, content)
        bg = bg:gsub('_', ';')
        local bg_color = ansi_colors[bg] or ''
        return '<span background="' .. bg_color .. '">' .. content .. '</span>'
    end)

    -- Clean up any remaining placeholders
    text = text:gsub('<BG[^>]+>', '')
    text = text:gsub('<FG[^>]+>', '')
    text = text:gsub('<RESET>', '')
    text = text:gsub('<BOLD>', '')

    return text
end

-- Fetch and display terminal output
local function fetch_terminal_output(callback)
    local no_dates_flag = config.show_dates and "" or "--no-dates"
    local cmd = string.format(
        'python3 "%s" terminal --weeks %d %s 2>/dev/null',
        config.script_path, config.weeks, no_dates_flag
    )

    awful.spawn.easy_async_with_shell(cmd, function(stdout, stderr, reason, exit_code)
        if exit_code ~= 0 or stdout == "" then
            callback('<span foreground="#ff0000">Error: Failed to fetch uptime data</span>')
            return
        end

        -- Convert ANSI codes to Pango markup
        local pango_output = ansi_to_pango(stdout)

        callback('<span font="monospace 9">' .. pango_output .. '</span>')
    end)
end

-- Update the graph with terminal output
local function update_graph(popup_widget)
    local graph_container = popup_widget:get_children_by_id("graph_container")[1]

    fetch_terminal_output(function(output)
        graph_container.markup = output
    end)
end

-- Create the popup window
local popup = awful.popup {
    widget = {
        {
            create_popup_widget(),
            margins = 20,
            widget = wibox.container.margin,
        },
        bg = colors.background,
        widget = wibox.container.background,
    },
    visible = false,
    ontop = true,
    placement = awful.placement.centered,
    shape = function(cr, width, height)
        gears.shape.rounded_rect(cr, width, height, 10)
    end,
    border_width = 2,
    border_color = colors.border,
    minimum_width = config.popup_width,
    minimum_height = config.popup_height,
}

-- Function to refresh the popup data
local function refresh_popup()
    if not popup.widget then return end

    local content = popup.widget:get_children()[1]:get_children()[1]
    update_graph(content)
end

-- Toggle popup visibility
local function toggle_popup()
    if popup.visible then
        popup.visible = false
    else
        refresh_popup()
        popup.visible = true
    end
end

-- Set up the widget icon click handler
widget_icon:buttons(gears.table.join(
    awful.button({}, 1, function()
        toggle_popup()
    end)
))

-- Auto-refresh timer
local refresh_timer = gears.timer {
    timeout = config.update_interval,
    autostart = true,
    callback = function()
        if popup.visible then
            refresh_popup()
        end
    end
}

-- Return the widget
uptime_widget.widget = widget_icon
uptime_widget.toggle = toggle_popup
uptime_widget.refresh = refresh_popup

return uptime_widget
