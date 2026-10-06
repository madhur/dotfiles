---------------------------------------------------------------------------
--- Magnifier layout
--
-- @author Madhur Ahuja &lt;ahuja.madhur@gmail.com&gt;
-- @copyright 2023 Madhur Ahuja
-- @module madhur.layout
---------------------------------------------------------------------------

-- Grab environment we need
local awful = require("awful")
local naughty = require("naughty")
local ipairs = ipairs
local math = math
local capi = {
    client = client,
    screen = screen,
    mouse = mouse,
    mousegrabber = mousegrabber
}

--- The magnifier layout layoutbox icon.
-- @beautiful beautiful.layout_magnifier
-- @param surface
-- @see gears.surface

local centermaster = {}

function centermaster.mouse_resize_handler(c, corner, x, y)
    capi.mouse.coords({x = x, y = y})

    local wa = c.screen.workarea
    local center_x = wa.x + wa.width / 2
    local center_y = wa.y + wa.height / 2
    local maxdist_pow = (wa.width ^ 2 + wa.height ^ 2) / 4

    local prev_coords = {}
    capi.mousegrabber.run(
        function(position)
            if not c.valid then
                return false
            end

            for _, v in ipairs(position.buttons) do
                if v then
                    prev_coords = {x = position.x, y = position.y}
                    local dx = center_x - position.x
                    local dy = center_y - position.y
                    local dist = dx ^ 2 + dy ^ 2

                    -- New master width factor
                    local mwfact = dist / maxdist_pow
                    c.screen.selected_tag.master_width_factor = math.min(math.max(0.01, mwfact), 0.99)
                    return true
                end
            end
            return prev_coords.x == position.x and prev_coords.y == position.y
        end,
        corner .. "_corner"
    )
end

local function get_screen(s)
    return s and capi.screen[s]
end

function centermaster.arrange(p)
    -- Fullscreen?
    local area = p.workarea
    local cls = p.clients
    local t = p.tag or capi.screen[p.screen].selected_tag
    local mwfact = t.master_width_factor

    if #cls == 0 then
        return
    end
    -- We take master as the magnified client, instead of focussed one.
    local master = awful.client.getmaster(awful.screen.focused())

    -- we dont want to touch floating masters
    if master.floating then
        return
    end

    if not master then
        return
    end

    master:raise()

    local geometry = {}
    if #cls > 1 then
        geometry.width = area.width * math.sqrt(mwfact)
        geometry.height = area.height * math.sqrt(mwfact)
        geometry.x = area.x + (area.width - geometry.width) / 2
        geometry.y = area.y + (area.height - geometry.height) / 2
    else
        geometry.x = area.x
        geometry.y = area.y
        geometry.width = area.width
        geometry.height = area.height
    end

    local g = {
        x = geometry.x,
        y = geometry.y,
        width = geometry.width,
        height = geometry.height
    }
    p.geometries[master] = g

    if #cls > 1 then
        geometry.x = area.x
        geometry.y = area.y
        geometry.height = area.height / (#cls - 1)
        geometry.width = area.width

        for k = 2, #cls do
            p.geometries[cls[k]] = {
                x = geometry.x,
                y = geometry.y,
                width = geometry.width,
                height = geometry.height
            }
            geometry.y = geometry.y + geometry.height
        end
    end
end

--- The magnifier layout.
-- @clientlayout awful.layout.suit.magnifier
-- @usebeautiful beautiful.layout_magnifier

centermaster.name = "centermaster"

return centermaster

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
