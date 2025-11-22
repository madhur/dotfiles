-- Uptime Tracker Widget for AwesomeWM
-- Displays GitHub-style contribution graph with date tooltips
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
    weeks = 16, -- Number of weeks to display (matching user's conky config)
    popup_width = 800,
    popup_height = 400,
}

-- Color scheme matching Conky colors (GitHub-style)
local colors = {
    [0] = "#161b22", -- Dark gray (no activity)
    [1] = "#0e4429", -- Dark green (low activity)
    [2] = "#006d32", -- Medium green
    [3] = "#26a641", -- Bright green
    [4] = "#39d353", -- Brightest green (high activity)
    today_border = "#58a6ff", -- Blue border for today
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

-- Function to get uptime level from percentage
local function get_uptime_level(percentage)
    if percentage == 0 then
        return 0
    elseif percentage <= 20 then
        return 1
    elseif percentage <= 40 then
        return 2
    elseif percentage <= 60 then
        return 3
    else
        return 4
    end
end

-- Function to parse uptime data from script
local function fetch_uptime_data(callback)
    awful.spawn.easy_async_with_shell(
        string.format("python3 %s display --weeks %d --format grid 2>/dev/null || echo 'ERROR'",
            config.script_path, config.weeks),
        function(stdout, stderr, reason, exit_code)
            if exit_code ~= 0 or stdout:match("ERROR") then
                naughty.notify({
                    preset = naughty.config.presets.critical,
                    title = "Uptime Tracker Error",
                    text = "Failed to fetch uptime data\n" .. (stderr or "")
                })
                return
            end
            
            -- Parse the output to extract data
            -- We'll need to fetch raw data separately for date mapping
            awful.spawn.easy_async_with_shell(
                string.format("python3 %s raw --weeks %d 2>/dev/null",
                    config.script_path, config.weeks),
                function(raw_output)
                    callback(stdout, raw_output)
                end
            )
        end
    )
end

-- Function to create a single cell widget
local function create_cell(percentage, date_str, is_today)
    local level = get_uptime_level(percentage)
    local color = colors[level]
    
    -- Square cells like GitHub - use constraint to enforce square dimensions
    local cell_size = 11  -- GitHub uses ~11px squares
    local inner_cell = wibox.widget {
        widget = wibox.container.background,
        bg = color,
        shape = gears.shape.rectangle,
    }
    
    -- Wrap in constraint to enforce square size
 -- Method 1: Using forced width/height (recommended)
local cell = wibox.widget {
    {
        widget = wibox.container.background,
        bg = color,
        shape = gears.shape.rectangle,
    },
    forced_width = cell_size,
    forced_height = cell_size,
    widget = wibox.container.constraint,
}
    
    -- Add border for today's cell using background container
    if is_today then
        cell = wibox.widget {
            cell,
            border_width = 2,
            border_color = colors.today_border,
            widget = wibox.container.background,
        }
    end
    
    -- Create tooltip for this cell
    local hours = string.format("%.1f", (percentage / 100) * 24)
    local tooltip_text = string.format("%s\n%s%% uptime (%s hours)", 
        date_str, percentage, hours)
    
    local cell_tooltip = awful.tooltip {
        objects = { cell },
        text = tooltip_text,
        mode = "mouse",
        delay_show = 0.1,
    }
    
    -- Hover effect - only for today's cell
    if is_today then
        cell:connect_signal("mouse::enter", function()
            cell.border_width = 2
            cell.border_color = "#ffffff"
        end)
        
        cell:connect_signal("mouse::leave", function()
            cell.border_width = 2
            cell.border_color = colors.today_border
        end)
    end
    
    return cell
end

-- Function to parse date from raw output and create data structure
local function parse_uptime_data(raw_output)
    local data = {}
    local lines = {}
    
    for line in raw_output:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    -- Parse the raw output to extract dates and percentages
    -- The format has day labels and weekly data
    local current_date = os.date("*t")
    local days_back = 0
    
    -- Calculate start date (going back weeks * 7 days, aligned to Sunday)
    local start_time = os.time() - (config.weeks * 7 * 86400)
    local start_date = os.date("*t", start_time)
    
    -- Align to Sunday
    local days_since_sunday = (start_date.wday - 1)
    start_time = start_time - (days_since_sunday * 86400)
    
    -- Generate date grid
    for week = 0, config.weeks - 1 do
        data[week] = {}
        for day = 0, 6 do
            local date_time = start_time + ((week * 7 + day) * 86400)
            local date = os.date("*t", date_time)
            data[week][day] = {
                date_str = os.date("%Y-%m-%d", date_time),
                display_str = os.date("%b %d, %Y", date_time),
                percentage = 0, -- Will be filled by actual data
                is_today = (os.date("%Y-%m-%d", date_time) == os.date("%Y-%m-%d")),
            }
        end
    end
    
    return data
end

-- Function to fetch actual percentages from the Python script
local function fetch_percentages(data, callback)
    local dates_to_fetch = {}
    
    for week = 0, config.weeks - 1 do
        for day = 0, 6 do
            if data[week] and data[week][day] then
                table.insert(dates_to_fetch, data[week][day].date_str)
            end
        end
    end
    
    -- Fetch percentages for all dates
    local fetch_commands = {}
    for _, date_str in ipairs(dates_to_fetch) do
        local days_back = math.floor((os.time() - os.time(os.date("*t", os.time{
            year = tonumber(date_str:sub(1, 4)),
            month = tonumber(date_str:sub(6, 7)),
            day = tonumber(date_str:sub(9, 10))
        }))) / 86400)
        
        table.insert(fetch_commands, string.format(
            "python3 %s display --format conky-bar --bar-type day-%d 2>/dev/null",
            config.script_path, days_back
        ))
    end
    
    -- Execute all commands and collect results
    local results = {}
    local completed = 0
    
    for i, cmd in ipairs(fetch_commands) do
        awful.spawn.easy_async_with_shell(cmd, function(stdout)
            results[i] = tonumber(stdout:match("%d+")) or 0
            completed = completed + 1
            
            if completed == #fetch_commands then
                -- Update data with percentages
                local idx = 1
                for week = 0, config.weeks - 1 do
                    for day = 0, 6 do
                        if data[week] and data[week][day] then
                            data[week][day].percentage = results[idx] or 0
                            idx = idx + 1
                        end
                    end
                end
                callback(data)
            end
        end)
    end
end

-- Simplified approach: Use the script's output directly
local function fetch_data_simple(callback)
    -- Get the current date for marking today
    local today = os.date("%Y-%m-%d")
    local now = os.time()
    local now_table = os.date("*t", now)
    
    -- Calculate grid of dates - match Python script's logic exactly
    local data = {}
    
    -- Find the Sunday of the current week
    -- Lua wday: 1=Sunday, 2=Monday, ..., 7=Saturday
    -- Python weekday: 0=Monday, 1=Tuesday, ..., 6=Sunday
    -- So for Lua: days_since_sunday = (wday - 1) % 7, but we need to handle it differently
    local days_since_sunday
    if now_table.wday == 1 then
        days_since_sunday = 0  -- Sunday
    else
        days_since_sunday = now_table.wday - 1  -- Monday=1, Tuesday=2, etc.
    end
    local current_week_sunday = now - (days_since_sunday * 86400)
    
    -- Calculate start date: go back (weeks - 1) weeks from current Sunday
    -- This matches Python: start_date = current_week_sunday - timedelta(weeks=weeks_to_show-1)
    local start_time = current_week_sunday - ((config.weeks - 1) * 7 * 86400)
    
    -- Generate all dates and fetch their percentages
    local all_dates = {}
    for week = 0, config.weeks - 1 do
        data[week] = {}
        for day = 0, 6 do
            local date_time = start_time + ((week * 7 + day) * 86400)
            
            -- Only include dates up to today
            if date_time <= now then
                local date_str = os.date("%Y-%m-%d", date_time)
                local display_str = os.date("%b %d, %Y", date_time)
                local is_today = (date_str == today)
                
                data[week][day] = {
                    date_str = date_str,
                    display_str = display_str,
                    percentage = 0,
                    is_today = is_today,
                }
                
                -- Calculate days back from today for the script
                local days_back = math.floor((now - date_time) / 86400)
                
                table.insert(all_dates, {
                    week = week,
                    day = day,
                    date_str = date_str,
                    days_back = days_back,
                })
            else
                -- Future date - empty cell
                data[week][day] = nil
            end
        end
    end
    
    -- Fetch all percentages efficiently
    local fetch_count = #all_dates
    
    if fetch_count == 0 then
        callback(data)
        return
    end
    
    -- Fetch percentages for each date individually (more reliable than batch)
    local results = {}
    local completed = 0
    local total_requests = #all_dates
    
    if total_requests == 0 then
        callback(data)
        return
    end
    
    for i, date_info in ipairs(all_dates) do
        local cmd = string.format(
            'python3 "%s" display --format conky-bar --bar-type day-%d 2>/dev/null',
            config.script_path, date_info.days_back
        )
        
        awful.spawn.easy_async_with_shell(cmd, function(stdout, stderr, reason, exit_code)
            -- Parse the output (should be just a number)
            local pct = tonumber(stdout:match("%d+")) or 0
            results[i] = pct
            completed = completed + 1
            
            -- When all requests are done, update data and callback
            if completed == total_requests then
                for j, date_info in ipairs(all_dates) do
                    if results[j] and data[date_info.week] and data[date_info.week][date_info.day] then
                        data[date_info.week][date_info.day].percentage = results[j]
                    end
                end
                callback(data)
            end
        end)
    end
end

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
            layout = wibox.layout.fixed.vertical,
        },
        {
            {
                markup = '<span foreground="' .. colors.text .. '">Loading...</span>',
                id = "summary_text",
                align = "center",
                widget = wibox.widget.textbox,
            },
            top = 10,
            bottom = 10,
            widget = wibox.container.margin,
        },
        layout = wibox.layout.fixed.vertical,
    }
    
    return popup_widget
end

-- Update the graph with data
local function update_graph(popup_widget, data)
    local graph_container = popup_widget:get_children_by_id("graph_container")[1]
    graph_container:reset()
    
    -- Create month labels
    local month_labels = wibox.widget {
        {
            markup = '<span foreground="' .. colors.text .. '">     </span>', -- Spacing for day labels
            widget = wibox.widget.textbox,
        },
        spacing = 3, -- Spacing between month labels (matches cell spacing)
        layout = wibox.layout.fixed.horizontal,
    }
    
    local current_month = nil
    for week = 0, config.weeks - 1 do
        if data[week] and data[week][0] then
            local month = data[week][0].date_str:sub(6, 7)
            if month ~= current_month then
                local month_name = os.date("%b", os.time{
                    year = tonumber(data[week][0].date_str:sub(1, 4)),
                    month = tonumber(month),
                    day = 1
                })
                month_labels:add(wibox.widget {
                    markup = '<span foreground="' .. colors.text .. '">' .. month_name:sub(1, 1) .. '</span>',
                    forced_width = 17,
                    align = "center",
                    widget = wibox.widget.textbox,
                })
                current_month = month
            else
                month_labels:add(wibox.widget {
                    markup = ' ',
                    forced_width = 17,
                    widget = wibox.widget.textbox,
                })
            end
        end
    end
    
    graph_container:add(month_labels)
    
    -- Create day rows
    local day_labels = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}
    
    for day = 0, 6 do
        local row = wibox.widget {
            {
                markup = '<span foreground="' .. colors.text .. '">' .. day_labels[day + 1] .. '</span>',
                forced_width = 35,
                align = "left",
                widget = wibox.widget.textbox,
            },
            spacing = 3, -- GitHub uses 3px spacing between cells
            layout = wibox.layout.fixed.horizontal,
        }
        
        for week = 0, config.weeks - 1 do
            if data[week] and data[week][day] then
                local cell_data = data[week][day]
                local cell = create_cell(
                    cell_data.percentage,
                    cell_data.display_str,
                    cell_data.is_today
                )
                row:add(cell)
            else
                -- Empty space for future dates (matching cell size)
                row:add(wibox.widget {
                    {
                        widget = wibox.container.background,
                    },
                    width = 11,
                    height = 11,
                    strategy = "exact",
                    widget = wibox.container.constraint,
                })
            end
        end
        
        graph_container:add(row)
    end
    
    -- Add legend
    local legend = wibox.widget {
        {
            markup = '<span foreground="' .. colors.text .. '">Less</span>',
            widget = wibox.widget.textbox,
        },
        spacing = 5,
        layout = wibox.layout.fixed.horizontal,
    }
    
    for i = 0, 4 do
        legend:add(wibox.widget {
            {
                widget = wibox.container.background,
                bg = colors[i],
                shape = gears.shape.rectangle,
            },
            width = 11,
            height = 11,
            strategy = "exact",
            widget = wibox.container.constraint,
        })
    end
    
    legend:add(wibox.widget {
        markup = '<span foreground="' .. colors.text .. '">More</span>',
        widget = wibox.widget.textbox,
    })
    
    graph_container:add(wibox.widget {
        legend,
        top = 15,
        left = 35,
        widget = wibox.container.margin,
    })
    
    -- Update summary
    local summary = popup_widget:get_children_by_id("summary_text")[1]
    
    -- Calculate statistics
    local good_days = 0
    local total_days = 0
    
    for week = 0, config.weeks - 1 do
        for day = 0, 6 do
            if data[week] and data[week][day] and data[week][day].percentage > 0 then
                total_days = total_days + 1
                if data[week][day].percentage > 75 then
                    good_days = good_days + 1
                end
            end
        end
    end
    
    local today_pct = 0
    for week = 0, config.weeks - 1 do
        for day = 0, 6 do
            if data[week] and data[week][day] and data[week][day].is_today then
                today_pct = data[week][day].percentage
            end
        end
    end
    
    local summary_text = string.format(
        "%d high uptime days in the last %d weeks. Today: %d%%",
        good_days, config.weeks, today_pct
    )
    
    summary.markup = '<span foreground="' .. colors.text .. '">' .. summary_text .. '</span>'
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
    
    fetch_data_simple(function(data)
        update_graph(content, data)
    end)
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