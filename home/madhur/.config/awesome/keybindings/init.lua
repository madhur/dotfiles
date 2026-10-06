local gears = require("gears")

gears.table.join(
    require("keybindings.mousebindings"),
    require("keybindings.clientkeys"),
    require("keybindings.globalkeys")
)
