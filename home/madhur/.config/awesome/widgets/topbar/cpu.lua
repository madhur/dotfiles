local cpu_widget = require("awesome-wm-widgets.cpu-widget.cpu-widget")
-- return cpu_widget

return cpu_widget({
    width = 70,
    step_width = 2,
    step_spacing = 1,
    color = '#434c5e',
    enable_kill_button = true
})

