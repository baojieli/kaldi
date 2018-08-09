#!/usr/bin/env python3

import sys
import os

if not len(sys.argv) == 3:
  print("Usage: seg_to_vad.py <segments> <data_dir_out>")
  print("  warning: directory needs utt2num_frames")
  exit()

seg_file = sys.argv[1]
data_dir = sys.argv[2]

frame_len = 0.01
multiplier = 1/frame_len

frame_dir = {}
with open(os.path.join(data_dir, 'utt2num_frames'), 'r') as utt2numF:
  for line in utt2numF:
    info = line.rstrip().split()
    frame_dir[info[0]] = int(info[1])

vadF = open(os.path.join(data_dir, 'vad.txt'), 'w')

prev_reco = ""
prev_end = 0
with open(seg_file, 'r') as segF:
  for line in segF:
    info = line.rstrip().split()

    # Check if it is a new recording
    if info[1] != prev_reco:
      if prev_reco:
        for i in range(frame_dir[prev_reco]-prev_end):
          vadF.write(" 0")
        vadF.write(" ]\n")
      vadF.write(info[1]+"  [")
      prev_end = 0
    prev_reco = info[1]

    zeros = round(float(info[2])*multiplier)-prev_end
    ones = round(float(info[3])*multiplier-float(info[2])*multiplier)
    for i in range(zeros):
      vadF.write(" 0")
    for i in range(ones):
      vadF.write(" 1")

    prev_end = round(float(info[3])*multiplier)

for i in range(frame_dir[prev_reco]-prev_end):
  vadF.write(" 0")
vadF.write(" ]")

vadF.close()
