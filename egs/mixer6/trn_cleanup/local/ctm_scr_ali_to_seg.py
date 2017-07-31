#!/usr/bin/env python

import sys

if not len(sys.argv) == 7:
  print("usage: "+sys.argv[0]+" <utt_id> <utt_len> <ctm_times> <script> <alignment> <segments_out>")
  sys.exit(1)

utt = sys.argv[1]
length = sys.argv[2]
ctm = sys.argv[3]
script = sys.argv[4]
ali = sys.argv[5]
segments = sys.argv[6]

time_padding = 0.1

times = []
with open(ctm,'r') as times_file:
  for line in times_file:
    split = line.split()
    times.append((max(float(split[0])-time_padding,0),min(float(split[0])+float(split[1])+time_padding,float(length))))

inds = []
count = 0
with open(script,'r') as scr_file:
  for line in scr_file:
    split = line.split()
    inds.append((count+1,count+len(split)))
    count = count+len(split)

seg_times = []
ctm_ind = 0
scr_ind = 0
inds_ind = 0
with open(ali,'r') as ali_file:
  for line in ali_file:
    line = line.rstrip()
    split = line.split()
    if not split[0] == "<eps>":
      ctm_ind = ctm_ind+1
    if not split[1] == "<eps>":
      scr_ind = scr_ind+1
    if inds_ind < len(inds):
      if scr_ind == inds[inds_ind][0]:
        if ctm_ind > 0:
          seg_time = [times[ctm_ind-1][0]]
        else:
          seg_time = [times[0][0]]
      if scr_ind == inds[inds_ind][1]:
        if ctm_ind > 0:
          seg_time.append(times[ctm_ind-1][1])
        else:
          seg_time.append(times[0][1])
        seg_times.append(seg_time)
        inds_ind = inds_ind+1

outF = open(segments, 'w')
for i in range(len(seg_times)):
  outF.write(utt+'_'+str(i).zfill(3)+' '+utt+' '+str(seg_times[i][0])+' '+ str(seg_times[i][1])+'\n')
