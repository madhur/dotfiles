
local rawget = rawget

function wrequire(t, k)
    return rawget(t, k) or require(t._NAME .. '.' .. k)
end
local setmetatable = setmetatable

local layout       = { _NAME = "widgets.topbar" }

return setmetatable(layout, { __index = wrequire })
