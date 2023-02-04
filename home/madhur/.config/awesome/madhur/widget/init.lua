
local rawget = rawget

function wrequire(t, k)
    return rawget(t, k) or require(t._NAME .. '.' .. k)
end
local setmetatable = setmetatable

local widget = { _NAME = "madhur.widget" }

return setmetatable(widget, { __index = wrequire })