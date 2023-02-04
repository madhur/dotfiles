#!/usr/bin/env python
import i3ipc, re, mmap
r = re.compile(r'chrom|telegram|Master PDF Editor|typora',re.I)
fd = open("/tmp/libinput_discrete_deltay_multiplier","r+b")
m = mmap.mmap(fd.fileno(), 0, access=mmap.ACCESS_WRITE)
def on_window_focus(i3, e):
    v = 1
    c = e.container.window_class
    if not c:
        return
    if (r.search(c)):
        v = 6
    m.seek(0)
    m.write(str(v).encode())

i3 = i3ipc.Connection()
i3.on("window::focus", on_window_focus)
i3.main()
