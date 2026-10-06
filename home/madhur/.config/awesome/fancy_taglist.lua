-- awesomewm fancy_taglist: a taglist that contains a tasklist for each tag.

-- Usage:
-- 1. Save as "fancy_taglist.lua" in ~/.config/awesome
-- 2. Add a fancy_taglist for every screen:
--          awful.screen.connect_for_each_screen(function(s)
--              ...
--              local fancy_taglist = require("fancy_taglist")
--              s.mytaglist = fancy_taglist.new({
--                  screen = s,
--                  taglist_buttons = mytagbuttons,
--                  tasklist_buttons = mytasklistbuttons
--              })
--              ...
--          end)
-- 3. Add s.mytaglist to your wibar.

local awful = require("awful")
local wibox = require("wibox")
local icons = require("icons")
local beautiful = require("beautiful")

local module = {}


local generate_filter = function(t)
	return function(c, scr)
		local ctags = c:tags()
		for _, v in ipairs(ctags) do
			if v == t then
				return true
			end
		end
		return false
	end
end

local fancytasklist = function(cfg, t)
	return awful.widget.tasklist(
		{
			screen = cfg.screen or awful.screen.focused(),
			filter = generate_filter(t),
			buttons = cfg.tasklist_buttons,
			widget_template = {
				{
					id = "clienttext",
					widget = wibox.widget.textbox,
					markup = ""
				},
				create_callback = function(self, c, _, _)
					local icon = nil
					if icons[c.class] then
						icon = icons[c.class]
					else
						icon = icons.default
					end
					self:get_children_by_id("clienttext")[1].markup = " " .. icon .. " "
				end,

				layout = wibox.container.background
			}
		}
	)
end

function module.new(config)
	local cfg = config or {}
	local spr =
		wibox.widget {
		markup = " ",
		align = "left",
		valign = "center",
		widget = wibox.widget.textbox
	}


	local s = cfg.screen or awful.screen.focused()
	local taglist_buttons = cfg.taglist_buttons

	return awful.widget.taglist(
		{
			screen = s,
			filter = awful.widget.taglist.filter.noempty,
			widget_template = {
				{
					{
						id="top_border",
						widget = wibox.widget.separator,
						forced_height = 2,
						thickness=2,
						forced_width=80,
						orientation="horizontal",
						color = beautiful.taglist_border_color
					},
					{
						{
							-- tag
							{
								id = "text_role",
								widget = wibox.widget.textbox,
								align = "center"
							},
							-- tasklist
							{
								id = "tasklist_placeholder",
								layout = wibox.layout.fixed.horizontal
							},
							spr,
							--border,
							layout = wibox.layout.fixed.horizontal
						},
						id = "background_role",
						widget = wibox.container.background
					},
					layout = wibox.layout.fixed.vertical
				},
				layout = wibox.layout.fixed.horizontal,
				create_callback = function(self, tag, _, _)
					self:get_children_by_id("tasklist_placeholder")[1]:add(fancytasklist(cfg, tag))
					if not string.find(tag.name, ":") and #tag:clients() > 0 then
						tag.name = tag.name .. ":"
					elseif string.find(tag.name, ":") and #tag:clients() == 0 then
						tag.name = tag.name:sub(1, -2)
					end
					if not tag.selected then
						self:get_children_by_id("top_border")[1].color = beautiful.darker
					elseif tag.selected then
						self:get_children_by_id("top_border")[1].color = beautiful.taglist_border_color
					end
				end,
				update_callback = function(self, tag, _, _)
					if not tag.selected then
						self:get_children_by_id("top_border")[1].color = beautiful.darker
					elseif tag.selected then
						self:get_children_by_id("top_border")[1].color = beautiful.taglist_border_color
					end
					if not string.find(tag.name, ":") and #tag:clients() > 0 then
						tag.name = tag.name .. ":"
					elseif string.find(tag.name, ":") and #tag:clients() == 0 then
						tag.name = tag.name:sub(1, -2)
					end
				end
			},
			buttons = taglist_buttons
		}
	)
end

return module
