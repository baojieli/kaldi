#!/usr/bin/env python

import sys

ctm = sys.argv[1]

outfile = open(sys.argv[2],'w')

checking = True
prevline = "0 0 junk 0"
check_time = 0
with open(ctm,'r') as ctmfile:
  for line in ctmfile:
    split = prevline.rstrip().split()
    oldword = split[2]
    oldtime = float(split[0]+'.'+split[1])
    oldind = split[3]
    split = line.rstrip().split()
    newword = split[2]
    newtime = float(split[0]+'.'+split[1])
    newind = split[3]

    if checking:
      if (oldword == newword) and (abs(newtime-oldtime) < 0.1):
        outfile.write(str(min(int(oldind),int(newind)))+","+str(max(int(oldind),int(newind))-1)+"d;")
        checking = False
        check_time = float(oldtime)
    else:
      if float(oldtime) > check_time + 5:
        checking = True

    prevline = line

outfile.close()
