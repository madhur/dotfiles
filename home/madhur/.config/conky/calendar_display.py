#!/usr/bin/env python3
"""Calendar display for Conky with weekend and today highlighting."""

import calendar
from datetime import date

d = date.today()
c = calendar.TextCalendar(0)  # Monday first
lines = c.formatmonth(d.year, d.month).rstrip().split('\n')

for i, line in enumerate(lines):
    if i < 2:
        print('     ' + line.lower())
        continue
    parts = []
    padded = line.ljust(20)
    for col in range(7):
        s = col * 3
        chunk = padded[s:s + 3]
        num = chunk.strip()
        if num and num.isdigit():
            n = int(num)
            if n == d.day:
                parts.append(chunk.replace(num, '${color5}' + num + '${color0}'))
            elif col == 5 or col == 6:
                parts.append(chunk.replace(num, '${color4}' + num + '${color0}'))
            else:
                parts.append(chunk)
        else:
            parts.append(chunk)
    print('     ' + ''.join(parts))
