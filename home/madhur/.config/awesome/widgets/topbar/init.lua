local rawget = rawget

function wrequire(t, k)
    return rawget(t, k) or require(t._NAME .. '.' .. k)
end
local setmetatable = setmetatable

local layout       = { _NAME = "widgets.topbar" }
layout.redshift = require("widgets.topbar.redshift")

return setmetatable(layout, { __index = wrequire })
