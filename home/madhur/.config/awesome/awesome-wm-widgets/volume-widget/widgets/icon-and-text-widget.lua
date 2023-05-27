local wibox = require("wibox")
local beautiful = require('beautiful')

local widget = {}

local ICON_DIR = os.getenv("HOME") .. '/.config/awesome/awesome-wm-widgets/volume-widget/icons/'

function widget.get_widget(widgets_args)
    local args = widgets_args or {}

    local font = args.font or beautiful.font
    local icon_dir = args.icon_dir or ICON_DIR

    return wibox.widget {
        -- {
        --     {
        --         id = "icon",
        --         resize = false,
        --         widget = wibox.widget.imagebox,
        --     },
        --     valign = 'center',
        --     layout = wibox.container.place
        -- },
        {
            id = 'txt',
            font = font,
            widget = wibox.widget.textbox
        },
        layout = wibox.layout.fixed.horizontal,
        set_volume_level = function(self, new_value, force)
          
            local volume_icon_name
            local new_value_num

            if self.is_muted then
                volume_icon_name = ' '
            else
                new_value_num = tonumber(math.floor(new_value+0.5))
                if (new_value_num >= 0 and new_value_num < 33) then
                    volume_icon_name=" "
                elseif (new_value_num < 66) then
                    volume_icon_name=" "
                else
                    volume_icon_name=" "
                end
            end
            if force then
                awesome.emit_signal("warning", "volume_new")
            else
                awesome.emit_signal("normal", "volume_new")
            end
            -- self:get_children_by_id('icon')[1]:set_image(icon_dir .. volume_icon_name .. '.svg')
            self:get_children_by_id('txt')[1]:set_text(volume_icon_name.." "..new_value_num)
        end,
        mute = function(self)
            self.is_muted = true
            self:get_children_by_id('txt')[1]:set_text(" ")
            awesome.emit_signal("critical", "volume_new")
            -- self:get_children_by_id('icon')[1]:set_image(icon_dir .. 'audio-volume-muted-symbolic.svg')
        end,
        unmute = function(self)
            self.is_muted = false
        end
    }

end


return widget