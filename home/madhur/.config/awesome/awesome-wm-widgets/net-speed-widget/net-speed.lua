-------------------------------------------------
-- Net Speed Widget for Awesome Window Manager
-- Shows current upload/download speed
-- More details could be found here:
-- https://github.com/streetturtle/awesome-wm-widgets/tree/master/net-speed-widget

-- @author Pavel Makhov
-- @copyright 2020 Pavel Makhov
-------------------------------------------------

local watch = require("awful.widget.watch")
local wibox = require("wibox")
local helpers = require("madhur.helpers")
local HOME_DIR = os.getenv("HOME")
local spawn  = require("awful.spawn")
local WIDGET_DIR = HOME_DIR .. '/.config/awesome/awesome-wm-widgets/net-speed-widget/'
local ICONS_DIR = WIDGET_DIR .. 'icons/'
local awful = require("awful")
local naughty = require("naughty")

local net_speed_widget = {}
local warn_count = 0
local crit_count = 0
local is_connected = true
local ping_time = "N/A"

-- Function to parse ping time from ping output
local function parse_ping_time(stdout)
    if not stdout then return "N/A" end
    -- Match pattern: time=XX.X ms or time=XX ms
    local time_match = string.match(stdout, "time=([%d%.]+)%s*ms")
    if time_match then
        local time_value = tonumber(time_match)
        if time_value then
            -- Round to 1 decimal place
            return string.format("%.1f", time_value) .. "ms"
        end
    end
    return "N/A"
end

-- Function to check internet connectivity and capture ping time
local function check_connectivity()
    spawn.easy_async("ping -c 1 -W 1 8.8.8.8", function(stdout, stderr, exitreason, exitcode)
        local connected = exitcode == 0
        if connected then
            ping_time = parse_ping_time(stdout)
            -- Emit signal to update ping time
            awesome.emit_signal("net_ping_time_changed", ping_time)
        else
            ping_time = "N/A"
            awesome.emit_signal("net_ping_time_changed", ping_time)
        end
        if connected ~= is_connected then
            is_connected = connected
            -- Emit signal to update widget appearance
            awesome.emit_signal("net_connectivity_changed", is_connected)
        end
    end)
end

local function convert_to_h(bytes)
    local speed
    local dim
    local bits = bytes * 8
    if bits < 1000 then
        speed = bits
        dim = 'b/s'
    elseif bits < 1000000 then
        speed = bits/1000
        dim = 'kb/s'
    elseif bits < 1000000000 then
        speed = bits/1000000
        dim = 'mb/s'
    elseif bits < 1000000000000 then
        speed = bits/1000000000
        dim = 'gb/s'
    else
        speed = tonumber(bits)
        dim = 'b/s'
    end
   return math.floor(speed + 0.5) .. dim
end

local function split(string_to_split, separator)
    if separator == nil then separator = "%s" end
    local t = {}

    for str in string.gmatch(string_to_split, "([^".. separator .."]+)") do
        table.insert(t, str)
    end

    return t
end

local function emit_signals(speed)
    speed = speed*8 / 1000000
    if speed > 1 and speed < 100 then
        warn_count = warn_count + 1
        if warn_count > 3 then
            awesome.emit_signal("warning", "net_new")
        end
    elseif  speed >= 100 then
        crit_count = crit_count + 1
        if crit_count > 3 then
            awesome.emit_signal("critical", "net_new")            
        end
    else
        warn_count = 0
        crit_count = 0
        awesome.emit_signal("normal", "net_new")            
    end
end

local function worker(user_args)

    local args = user_args or {}

    local interface = args.interface or 'enp5s0'
    local timeout = args.timeout or 2
    local width = args.width or 150

    net_speed_widget = wibox.widget {
        {
            markup = " ",
            widget = wibox.widget.textbox
        },
        {
            id = 'rx_speed',
            forced_width = 120,
            align = 'right',
            widget = wibox.widget.textbox
        },
        -- {
        --     image = ICONS_DIR .. 'down.svg',
        --     widget = wibox.widget.imagebox
        -- },
        -- {
        --     image =  ICONS_DIR .. 'up.svg',
        --     widget = wibox.widget.imagebox
        -- },
        {
            id = 'tx_speed',
            forced_width = 120,
            align = 'right',
            widget = wibox.widget.textbox
        },
        {
            id = 'ping_time',
            forced_width = 70,
            align = 'left',
            text = "N/A",
            widget = wibox.widget.textbox
        },
        layout = wibox.layout.fixed.horizontal,
        set_rx_text = function(self, new_rx_speed)
            local text = " 󰶡 "..tostring(new_rx_speed)
            if is_connected then
                self:get_children_by_id('rx_speed')[1]:set_text(text)
            else
                self:get_children_by_id('rx_speed')[1]:set_markup('<span color="#FF0000">' .. text .. '</span>')
            end
        end,
        set_tx_text = function(self, new_tx_speed)
            local text = " 󰶣 "..tostring(new_tx_speed)
            if is_connected then
                self:get_children_by_id('tx_speed')[1]:set_text(text)
            else
                self:get_children_by_id('tx_speed')[1]:set_markup('<span color="#FF0000">' .. text .. '</span>')
            end
        end,
        set_ping_time = function(self, new_ping_time)
            if not self then return end
            local success, ping_widgets = pcall(function() return self:get_children_by_id('ping_time') end)
            if not success or not ping_widgets or #ping_widgets == 0 or not ping_widgets[1] then 
                return 
            end
            local ping_widget = ping_widgets[1]
            local text = " " .. tostring(new_ping_time or "N/A")
            if is_connected then
                ping_widget:set_text(text)
            else
                ping_widget:set_markup('<span color="#FF0000">' .. text .. '</span>')
            end
        end,
        set_connectivity = function(self, connected)
            is_connected = connected
            -- Update the widget appearance immediately
            local rx_widget = self:get_children_by_id('rx_speed')[1]
            local tx_widget = self:get_children_by_id('tx_speed')[1]
            local ping_widget = self:get_children_by_id('ping_time')[1]
            if rx_widget and tx_widget then
                local rx_text = rx_widget:get_text()
                local tx_text = tx_widget:get_text()
                if connected then
                    -- Use default theme colors when connected
                    rx_widget:set_text(rx_text)
                    tx_widget:set_text(tx_text)
                    if ping_widget then
                        local ping_text = ping_widget:get_text()
                        ping_widget:set_text(ping_text)
                    end
                else
                    -- Use red when disconnected
                    rx_widget:set_markup('<span color="#FF0000">' .. rx_text .. '</span>')
                    tx_widget:set_markup('<span color="#FF0000">' .. tx_text .. '</span>')
                    if ping_widget then
                        local ping_text = ping_widget:get_text()
                        ping_widget:set_markup('<span color="#FF0000">' .. ping_text .. '</span>')
                    end
                end
            end
        end
    }

    -- make sure these are not shared across different worker/widgets (e.g. two monitors)
    -- otherwise the speed will be randomly split among the worker in each monitor
    local prev_rx = 0
    local prev_tx = 0

    local update_widget = function(widget, stdout)

        local cur_vals = split(stdout, '\r\n')

        local cur_rx = 0
        local cur_tx = 0

        for i, v in ipairs(cur_vals) do
            if i%2 == 1 then cur_rx = cur_rx + v end
            if i%2 == 0 then cur_tx = cur_tx + v end
        end

        local speed_rx = (cur_rx - prev_rx) / timeout
        local speed_tx = (cur_tx - prev_tx) / timeout

        widget:set_rx_text(convert_to_h(speed_rx))
        widget:set_tx_text(convert_to_h(speed_tx))
        local speed
        if (speed_rx > speed_tx) then
            speed = speed_rx
        else
            speed = speed_tx
        end
        emit_signals(speed)

        prev_rx = cur_rx
        prev_tx = cur_tx
    end

    watch(string.format([[bash -c "cat /sys/class/net/%s/statistics/*_bytes"]], interface),
        timeout, update_widget, net_speed_widget)

    -- Connect to connectivity change signal
    awesome.connect_signal("net_connectivity_changed", function(connected)
        net_speed_widget:set_connectivity(connected)
    end)

    -- Connect to ping time change signal
    awesome.connect_signal("net_ping_time_changed", function(new_ping_time)
        if net_speed_widget and net_speed_widget.set_ping_time then
            net_speed_widget:set_ping_time(new_ping_time)
        end
    end)

    -- Start connectivity checking
    watch("ping -c 1 -W 1 8.8.8.8", 60, function()
        check_connectivity()
    end)

    -- Initial connectivity check - delayed by 30 seconds to avoid red text during boot
    awful.spawn.easy_async("sleep 30 && ping -c 1 -W 1 8.8.8.8", function(stdout, stderr, exitreason, exitcode)
        local connected = exitcode == 0
        is_connected = connected
        if connected then
            ping_time = parse_ping_time(stdout)
        else
            ping_time = "N/A"
        end
        if net_speed_widget and net_speed_widget.set_ping_time then
            net_speed_widget:set_ping_time(ping_time)
        end
        if net_speed_widget and net_speed_widget.set_connectivity then
            net_speed_widget:set_connectivity(connected)
        end
    end)

    return net_speed_widget

end

return setmetatable(net_speed_widget, { __call = function(_, ...) return worker(...) end })
