local gears = require("gears")

gears.table.join(
    require("widgets.menu"),
    require("widgets.taglist"),
    require("widgets.tasklist"),
    require("widgets.layoutbox"),
    require("widgets.wiboxes")
)