#!/usr/bin/env python

import sys
import os

min_seg_len = 0.3

def main():
  if not len(sys.argv) == 4:
    print "Usage: "+sys.argv[0]+" <vad-file> <frame-length> <session-id>"
    exit()

  vadfile = sys.argv[1]
  framelen = float(sys.argv[2])
  sess_id = sys.argv[3]

  segments = []

  prev_char = '0'
  count = 0
  with open(vadfile,'r') as vadF:
    for line in vadF:
      if not line[0] == prev_char:
        if prev_char == '1':
          segments[-1].append(count*framelen)
        elif prev_char == '0':
          segments.append([count*framelen])
      prev_char = line[0]
      count = count+1
  if prev_char == '1':
    segments[-1].append(count*framelen)

  max_time = count*framelen

  for i in range(len(segments)):
    if not len(segments[i]) == 2:
      print "INVALID SEGMENTS"
      exit()
    segments[i][0] = max(0, segments[i][0]-0.3)
    segments[i][1] = min(max_time, segments[i][1]+0.3)

  # Remove invalid silence segments
  invalid = True
  while invalid:
    invalid = False
    i = 1
    while i < len(segments):
      if segments[i][0]-segments[i-1][1] < min_seg_len:
        invalid = True
        segments[i-1][1] = segments[i][1]
        segments.pop(i)
      else:
        i = i+1

  # Remove invalid speech segments
  invalid = True
  while invalid:
    invalid = False
    i = 0
    while i < len(segments):
      if segments[i][1]-segments[i][0] < min_seg_len:
        invalid = True
        segments.pop(i)
      else:
        i = i+1

  for i in range(len(segments)):
    print(sess_id+"_"+str(i).zfill(3)+" "+sess_id+" "+str(segments[i][0])+' '+str(segments[i][1]))

if __name__ == '__main__':
  main()
