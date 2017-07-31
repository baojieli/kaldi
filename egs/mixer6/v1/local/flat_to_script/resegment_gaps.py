#!/usr/bin/env python

import sys

ctm = sys.argv[1]
end = sys.argv[2]
segments = sys.argv[3]

sil_window = 0.5

outF = open(segments,'w')

times = []

prev_end = 0
with open(ctm,'r') as ctmfile:
  for line in ctmfile:
    split = line.split()
    id = split[0]
    start = float(split[2])
    dur = float(split[3])

    if start-prev_end > sil_window:
      times.append((str(prev_end),str(start)))

    prev_end = start+dur

if float(end)-prev_end > sil_window:
  times.append((str(prev_end),end))

for i in range(len(times)):
  outline = id+"_"+str(i).zfill(3)+" "+id+" "+times[i][0]+" "+times[i][1]+'\n'
  outF.write(outline)

outF.close()
