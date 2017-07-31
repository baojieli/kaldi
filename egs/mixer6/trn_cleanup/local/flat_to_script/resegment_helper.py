#!/usr/bin/env python

import sys

timestep = 10
sil_window = 0.5

ctm = sys.argv[1]
end = sys.argv[2]
segments = sys.argv[3]

outF = open(segments,'w')

times = ["0.0"]

prev_end = 0
with open(ctm,'r') as ctmfile:
  for line in ctmfile:
    split = line.split()
    id = split[0]
    start = float(split[2])
    dur = float(split[3])

    if float(start)-prev_end > sil_window:
      times.append(str( (float(start)+prev_end)/2 ))

    prev_end = float(start)+float(dur)

last = times[0]
i = 1
while i < len(times):
  if float(times[i]) - float(last) < timestep:
    times.pop(i)
  else:
    last = times[i]
    i = i+1

times.append(end)
for i in range(len(times)-1):
  outline = id+"_"+str(i).zfill(3)+" "+id+" "+times[i]+" "+times[i+1]+'\n'
  outF.write(outline)

outF.close()
