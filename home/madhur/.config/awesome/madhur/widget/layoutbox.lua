---------------------------------------------------------------------------
--- Text only Layoutbox widget.
--
-- @author Madhur Ahuja &lt;ahuja.madhur@gmail.com&gt;
-- @classmod madhur.widget
---------------------------------------------------------------------------

local setmetatable = setmetatable
local capi = { screen = screen, tag = tag }
local layout = require("awful.layout")
local beautiful = require("beautiful")
local wibox = require("wibox")
local awful = require("awful")

local function get_screen(s)
    return s and capi.screen[s]
end

local layoutbox = { mt = {} }

local boxes = nil

local function update(w, screen)
    screen = get_screen(screen)
    local name = layout.getname(layout.get(screen))
    local magnified = ""
    if awful.util.magnifier then
        magnified = "  "
    end
    w.textbox.text   = name..magnified
end

local function update_from_tag(t)
    local screen = get_screen(t.screen)
    local w = boxes[screen]
    if w then
        update(w, screen)
    end
end

--- Create a layoutbox widget. It displays the name of layout instead of image unlike the out of the box layoutbox widget
-- @param screen The screen number that the layout will be represented for.
function layoutbox.new(screen)
    screen = get_screen(screen or 1)

    -- Do we already have the update callbacks registered?
    if boxes == nil then
        boxes = setmetatable({}, { __mode = "kv" })
        capi.tag.connect_signal("property::selected", update_from_tag)
        capi.tag.connect_signal("property::layout", update_from_tag)
        capi.tag.connect_signal("property::screen", function()
            for s, w in pairs(boxes) do
                if s.valid then
                    update(w, s)
                end
            end
        end)
        layoutbox.boxes = boxes
    end

    -- Do we already have a layoutbox for this screen?
    local w = boxes[screen]
    if not w then
        w = wibox.widget {
            {
                id     = "textbox",
                font   = beautiful.layoutbox_font,
                widget = wibox.widget.textbox
            },
            layout = wibox.layout.fixed.horizontal
        }

        update(w, screen)
        boxes[screen] = w
    end

    return w
end

function layoutbox.mt:__call(...)
    return layoutbox.new(...)
end

return setmetatable(layoutbox, layoutbox.mt)