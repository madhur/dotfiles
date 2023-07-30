#!/usr/bin/python3

import sys
from subprocess import Popen
import subprocess

args = ' '.join(sys.argv[1:])+"\n"
#print(args)
p = Popen("bc", stdin=subprocess.PIPE, shell=True,  stdout=subprocess.PIPE, stderr=subprocess.PIPE)
out = p.communicate(args.encode())[0]
result=out.decode("utf-8").rstrip()
#print(result)
exit_code = p.wait()
#print(exit_code)
command = "/home/madhur/bin/eww update result=" + result
p = Popen(command, stdin=subprocess.PIPE, shell=True,  stdout=subprocess.PIPE, stderr=subprocess.PIPE)
out = p.communicate(args.encode())[0]
