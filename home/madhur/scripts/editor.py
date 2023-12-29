#!/usr/bin/env python3

import sys
import os
import subprocess

myObject = {}
for line in sys.argv:
    if '=' not in line:
        continue
    print(line)
    key, value = line.rstrip("\n").split("=")
    myObject[key] = value

print(myObject)


idea_running = False
pl = subprocess.Popen(['ps', 'aux'], stdout=subprocess.PIPE).communicate()[0]
list_ps = pl.decode('utf-8')

if 'intellij' in list_ps:
    idea_running = True

if idea_running is True and 'java' in myObject['path']:
    print("Intellij found")
    os.system("flatpak run com.jetbrains.IntelliJ-IDEA-Community " + myObject['path'])
else:
    print("Intellij not found")
    os.system("nvim " + " +"+myObject['line'] + " " + myObject['path'])

