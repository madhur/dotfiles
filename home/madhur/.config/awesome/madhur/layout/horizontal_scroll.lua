-- horizontal_scroll.lua - Custom layout for AwesomeWM
-- Place this file in ~/.config/awesome/layouts/

local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")

local horizontal_scroll = { name = "horizontal_scroll" }

-- Layout function
function horizontal_scroll.arrange(p)
    local area = p.workarea
    local t = p.tag or screen[p.screen].selected_tag
    local clients = p.clients
    
    if #clients == 0 then return end
    
    -- Configuration
    local peek_width = 20  -- Width of adjacent window peek
    local gap = beautiful.useless_gap or 0
    local border_width = beautiful.border_width or 0
    
    -- Calculate main window dimensions
    local main_width = area.width - (2 * peek_width) - (2 * gap)
    local window_height = area.height - (2 * gap)
    
    -- Get currently focused client index
    local focused_idx = 1
    local focused_client = client.focus
    if focused_client then
        for i, c in ipairs(clients) do
            if c == focused_client then
                focused_idx = i
                break
            end
        end
    end
    
    -- First pass: unminimize all windows that should be visible
    for i, c in ipairs(clients) do
        if i == focused_idx or 
           (i == focused_idx - 1 and focused_idx > 1) or 
           (i == focused_idx + 1 and focused_idx < #clients) then
            c.minimized = false
        else
            c.minimized = true
        end
    end
    
    -- Second pass: position all visible clients
    for i, c in ipairs(clients) do
        if not c.minimized then
            local geometry = {}
            
            if i == focused_idx then
                -- Main centered window
                geometry = {
                    x = area.x + peek_width + gap,
                    y = area.y + gap,
                    width = main_width - 2 * border_width,
                    height = window_height - 2 * border_width
                }
                c:geometry(geometry)
                c:raise()
                
            elseif i == focused_idx - 1 then
                -- Left peek window - show only rightmost 20px
                geometry = {
                    x = area.x,  -- Start at screen edge
                    y = area.y + gap,
                    width = peek_width,  -- Only show peek_width
                    height = window_height - 2 * border_width
                }
                c:geometry(geometry)
                c:lower()  -- Keep it behind the main window
                
            elseif i == focused_idx + 1 then
                -- Right peek window - show only leftmost 20px
                geometry = {
                    x = area.x + area.width - peek_width,  -- Position at right edge
                    y = area.y + gap,
                    width = peek_width,  -- Only show peek_width
                    height = window_height - 2 * border_width
                }
                c:geometry(geometry)
                c:lower()  -- Keep it behind the main window
            end
        end
    end
end

-- Add key bindings for navigation
local function setup_keybindings()
    local globalkeys = gears.table.join(
        -- Navigate to previous window
        awful.key({ "Mod4" }, "Left", 
            function()
                awful.client.focus.byidx(-1)
                if client.focus then
                    client.focus:raise()
                end
            end,
            {description = "focus previous by index", group = "client"}),
        
        -- Navigate to next window  
        awful.key({ "Mod4" }, "Right",
            function()
                awful.client.focus.byidx(1)
                if client.focus then
                    client.focus:raise()
                end
            end,
            {description = "focus next by index", group = "client"}),
            
        -- Alternative with h/l vim-style
        awful.key({ "Mod4" }, "h",
            function()
                awful.client.focus.byidx(-1)
                if client.focus then
                    client.focus:raise()
                end
            end,
            {description = "focus previous by index", group = "client"}),
            
        awful.key({ "Mod4" }, "l",
            function()
                awful.client.focus.byidx(1)
                if client.focus then
                    client.focus:raise()
                end
            end,
            {description = "focus next by index", group = "client"})
    )
    
    return globalkeys
end

-- Signal connections for smooth transitions
local function setup_signals()
    -- Redraw layout when focus changes
    client.connect_signal("focus", function(c)
        if c and awful.layout.get(c.screen) == horizontal_scroll then
            -- Small delay to ensure focus is properly set
            gears.timer.delayed_call(function()
                awful.layout.arrange(c.screen)
            end)
        end
    end)
    
    -- Also handle when a client becomes active
    client.connect_signal("request::activate", function(c)
        if c and awful.layout.get(c.screen) == horizontal_scroll then
            gears.timer.delayed_call(function()
                awful.layout.arrange(c.screen)
            end)
        end
    end)
    
    -- Handle new clients
    client.connect_signal("manage", function(c)
        if awful.layout.get(c.screen) == horizontal_scroll then
            -- Focus new client
            c:emit_signal("request::activate", "new_client", {raise = true})
            gears.timer.delayed_call(function()
                awful.layout.arrange(c.screen)
            end)
        end
    end)
    
    -- Handle client removal
    client.connect_signal("unmanage", function(c)
        local screen = c.screen
        gears.timer.delayed_call(function()
            if awful.layout.get(screen) == horizontal_scroll then
                awful.layout.arrange(screen)
            end
        end)
    end)
    
    -- Handle minimization changes
    client.connect_signal("property::minimized", function(c)
        if awful.layout.get(c.screen) == horizontal_scroll then
            gears.timer.delayed_call(function()
                awful.layout.arrange(c.screen)
            end)
        end
    end)
end

-- Mouse support for clicking on peek windows
local function setup_mouse_support()
    -- Add mouse click detection on peek windows
    client.connect_signal("mouse::enter", function(c)
        if awful.layout.get(c.screen) == horizontal_scroll then
            c:emit_signal("request::activate", "mouse_enter", {raise = false})
        end
    end)
    
    client.connect_signal("button::press", function(c, x, y, button)
        if awful.layout.get(c.screen) == horizontal_scroll and button == 1 then
            c:emit_signal("request::activate", "mouse_click", {raise = true})
        end
    end)
end

-- Initialize the layout
local function init()
    setup_signals()
    setup_mouse_support()
end

-- Export layout
horizontal_scroll.init = init
return horizontal_scroll