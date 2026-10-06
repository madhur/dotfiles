local pacman_widget = require('awesome-wm-widgets.pacman-widget.pacman')

return pacman_widget {
    interval = 600, -- Refresh every 10 minutes
    popup_bg_color = '#222222',
    popup_border_width = 1,
    popup_border_color = '#7e7e7e',
    popup_height = 50, -- 10 packages shown in scrollable window
    popup_width = 500,
    polkit_agent_path = '/usr/bin/lxpolkit'
}