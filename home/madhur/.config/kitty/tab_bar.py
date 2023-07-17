#!/usr/bin/env python3

from kitty.fast_data_types import (
    Screen,
)

from kitty.utils import color_as_int

from kitty.tab_bar import (
    DrawData,
    ExtraData,
    TabBarData,
    as_rgb,
    draw_title,
)

# Draw tabs by splitting the full width of the window
def draw_tab(
        draw_data: DrawData, screen: Screen, tab: TabBarData,
        before: int, max_tab_length: int, index: int, is_last: bool,
        extra_data: ExtraData
) -> int:
    # Draw first space
    screen.draw(' ')

    # Draw title
    draw_title(draw_data, screen, tab, index, max_tab_length)

    title_length = screen.cursor.x - before

    # Truncate the title if it's too long
    if title_length + 1 > max_tab_length:
        screen.cursor.x = before + max_tab_length - 1
        screen.draw('… ')
    else:
        # Draw trailing spaces
        if is_last:
            # Draw the last tab to the end
            screen.draw(' ' * (screen.columns - screen.cursor.x))
        else:
            # Draw to max_tab_length
            screen.draw(' ' * (max_tab_length - title_length + 1))

    end = screen.cursor.x

    screen.cursor.bold = screen.cursor.italic = False
    screen.cursor.fg = 0

    if not is_last:
        screen.cursor.bg = as_rgb(color_as_int(draw_data.inactive_bg))

    screen.cursor.bg = 0

    return end
