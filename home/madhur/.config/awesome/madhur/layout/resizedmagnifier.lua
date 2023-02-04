
-- Grab environment we need
local awful = require("awful")
local helpers = require("madhur.helpers")

local capi =
{
    client = client
}

local resizedmagnifier = {}

function resizedmagnifier.arrange(p)
    local cls = p.clients
    local area = p.workarea

    if #cls == 0 then return end

    -- if #cls > 2 then
    --     helpers.debug("This layout does not support more than 2 clients")
    --     return
    -- end

    if #cls == 1 then
        local g = {
            x = area.x,
            y = area.y,
            width = area.width,
            height = area.height
        }
        p.geometries[cls[1]] = g
        return
    end

    if #cls == 2 then
        local focus  = capi.client.focus
        local width = area["width"]
        local height = area["height"]
        local filled_space = 0

        for c, _ in pairs(p.clients)  do
            local geom = {}
            geom.height = height
            geom.y = area["y"]
            if c > 2 then
                c.minimized = true
                goto continue
            end
            if focus == cls[c] then
                geom.width = width * 0.5
                if awful.util.magnifier then geom.width = geom.width * 1.3 end
                geom.x = filled_space
                filled_space = filled_space +  geom.width
            else
                geom.width = width  * 0.5
                if awful.util.magnifier then geom.width = geom.width * 0.7 end
                geom.x = filled_space
                filled_space = filled_space + geom.width
            end
            p.geometries[cls[c]] = geom
            ::continue::
        end

    end

end


resizedmagnifier.name = "resizedmagnifier"
return resizedmagnifier

