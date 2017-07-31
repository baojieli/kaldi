#!/usr/bin/env python

import sys
import os
import argparse

parser = argparse.ArgumentParser(description='Takes energy-based VAD and creates speech segments.')

parser.add_argument('vad_rspecifier', metavar='vad-rspecifier', help='vad.scp file')
parser.add_argument('segments_folder', metavar='segments-folder', help='file to write segment time markers to')

args = parser.parse_args()

window = 10
thresh = 0.33
minlen = 0.25

with open(args.vad_rspecifier,'r') as vadscp:
  for line in vadscp:
    line = line.rstrip()
    split = line.split()
    os.system("copy-vector --binary=false "+split[1]+" temp.txt")

    outfile = open(args.segments_folder+split[0]+"-seg.txt",'w')

    with open("temp.txt",'r') as vad:
      for vadline in vad:
        frames = vadline.split()
        frames = frames[1:-1]
        
        smoothed = []
        for i in range(len(frames)):
          sum = 0
          count = 0
          for j in range(-window+1,window):
            if ((i+j)>=0) and ((i+j)<len(frames)):
              sum = sum + int(frames[i+j])
              count = count + 1
          if 1.0*sum/count > thresh:
            smoothed.append(1)
          else:
            smoothed.append(0)

        current = 0
        segs = []
        for i in range(len(smoothed)):
          if not smoothed[i] == current:
            if current == 0:
              current = 1
            else:
              current = 0
            segs.append(i*0.01)
#            if len(segs) == 2:
#              outfile.write(str(segs[0])+','+str(segs[1])+'\n')
#              segs = []

        prevlen = len(segs)+1
        while not prevlen == len(segs):
          prevlen = len(segs)
          i = 0
          while i+1 < len(segs):
            if float(segs[i+1])-float(segs[i]) < minlen:
              del segs[i]
              del segs[i]
            i = i+1

        for i in range(0,len(segs)-len(segs)%2,2):
          outfile.write(str(segs[i])+','+str(segs[i+1])+'\n')
    outfile.close()
