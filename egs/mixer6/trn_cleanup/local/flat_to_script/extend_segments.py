#!/usr/bin/env python

import sys

buff = sys.argv[1]
segments = sys.argv[2]
time = sys.argv[3]

with open(segments,'r') as segfile:
  for line in segfile:
    split = line.split()
    start = float(split[2])
    end = float(split[3])
    split[2] = str(max(start-float(buff), 0))
    split[3] = str(min(end+float(buff), float(time)))
    outline = ""
    for i in range(len(split)):
      outline = outline+" "+split[i]
    print outline[1:]

