local awful = require("awful")
local naughty = require("naughty")

local helpers = {
    resize_master = false
}
local capi = {
    client = client
}

function helpers.magnify(cls, gs, wa)
    if not awful.util.magnifier then
        return
    end

    local focus = capi.client.focus
    local master = awful.client.getmaster(awful.screen.focused())
    if not helpers.resize_master and focus==master then
        return
    end


    for c = 1,#cls do
        if focus == cls[c] then
            local geom = gs[cls[c]]
            local height = geom["height"]
            local width = geom["width"]
            local x = geom["x"]
            local y = geom["y"]
            local newWidth = width*1.3
            local newHeight = height*1.3
            local deltaHeight = newHeight - height
            local deltaWidth = newWidth - width
            if newWidth < wa["width"] then
                geom["width"] = newWidth
            end
            if newHeight < wa["height"] then
                geom["height"] = newHeight
            end
            if x > deltaWidth then
                geom["x"] = x - deltaWidth
            end
            if y > deltaHeight then
                geom["y"] = y - deltaHeight
            end
            return
        end
    end
end

function helpers.debug(text)
    naughty.notify({text=helpers.dump(text)})
end

function helpers.dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do

          local key = k
          if type(key) == 'function' then
            key = 'function'
          end
          if type(key) == 'table' then
            key = 'table'
          end
          if type(key) ~= 'number' and type(key) ~='table' then key = '"'..key..'"' end
          s = s .. '['..key..'] = ' .. helpers.dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
end

-- {{{ Expose path as a Lua table
function helpers.pathtotable(dir)
    return setmetatable({ _path = dir },
        { __index = function(self, index)
            local path = self._path .. '/' .. index
            local f = io.open(path)
            if f then
                local s = f:read("*all")
                f:close()
                if s then
                    return s
                else
                    local o = { _path = path }
                    setmetatable(o, getmetatable(self))
                    return o
                end
            end
        end
    })
end

function helpers.is_portrait(screen)
    -- Get screen geometry
    local geometry = screen.geometry
    -- Return true if height > width (portrait), false otherwise (landscape)
    return geometry.height > geometry.width
end

-- awful.tag.incmwfact() just adds `delta` to the current master_width_factor
-- with plain float arithmetic. Repeated +/-0.05 presses drift off their exact
-- decimal value (e.g. 0.9500000000000004), and once a press overshoots 1 or 0
-- by even a tiny epsilon, awful's own setter silently rejects it -- mwfact
-- gets stuck just short of the edge no matter how many more times you press
-- the key. Round to 2 decimals every step so it can't drift past the bounds.
function helpers.incmwfact(delta, t)
    t = t or awful.screen.focused().selected_tag
    local new = t.master_width_factor + delta
    new = math.floor(new * 100 + 0.5) / 100
    t.master_width_factor = math.min(1, math.max(0, new))
end
-- }}}

return helpers