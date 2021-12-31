#!/usr/bin/env python2

import os
import re

print("Read tvrenamer.pl...")
with open("tvrenamer.pl", "r") as sSrcFH:
    rSrc = sSrcFH.read()    

print("Enable Win32::Console::ANSI...")
rDst = re.sub(
    r"#use Win32::Console::ANSI;",
    r"use Win32::Console::ANSI;",
    rSrc)

print("Write tvrenamer_win32.pl...")
with open("tvrenamer_win32.pl", "w") as DstFH:
    DstFH.write(rDst)

print("Compile tvrenamer_win32.pl -> tvrenamer.exe...")
os.system("local\\bin\\pp -o tvrenamer.exe tvrenamer_win32.pl")

print("Remove tvrenamer_win32.pl...")
os.unlink("tvrenamer_win32.pl")
