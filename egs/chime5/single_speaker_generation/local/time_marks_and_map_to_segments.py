#!/usr/bin/env python3

import sys
import os
import numpy as np

if not len(sys.argv) == 4:
  print("Usage: time_marks_and_map_to_segmentx.py <time_marks> <drift_map> <segments_dir_out>")
  exit()

trn_file = sys.argv[1]
map_file = sys.argv[2]
out_dir = sys.argv[3]

if not os.path.exists(out_dir):
  os.makedirs(out_dir)

mapF = open(map_file, 'r')
map_header = mapF.readline()
mics = map_header.rstrip().split('\t')[1:]
seg_Fs = []
for mic in mics:
  seg_Fs.append(open(os.path.join(out_dir, mic), 'w'))

segment_ids = []
end_times = []
spk_ids = []
for map_line in mapF:
  seg_id = map_line.split('\t')[0]
  segment_ids.append(seg_id)
  end_times.append(float(seg_id[-7:])/100)
  spk_ids.append(seg_id.split('_')[1])

reco_id = segment_ids[0].split('-')[0]

map_mat = np.loadtxt(map_file, delimiter='\t', skiprows=1, usecols=range(1,len(mics)+1))

map_index = 0
trnF = open(trn_file, 'r')
for trn_line in trnF:
  start_time = float(trn_line.split(' ')[0])
  end_time = float(trn_line.split(' ')[1])
  try:
    while start_time > end_times[map_index]:
      map_index = map_index+1
  except:
    print('trn line:')
    print(trn_line)
    print(map_file)
  for i in range(len(mics)):
    adj_start = start_time + map_mat[map_index][i]
    adj_end = end_time + map_mat[map_index][i]
    start_int = int(adj_start*100)
    end_int = int(adj_end*100)
    utt_id = '{:s}-{:s}_{:s}_{:07d}_{:07d}'.format(reco_id, mics[i], spk_ids[map_index], start_int, end_int)
    seg_Fs[i].write('{:s} {:s}-{:s} {:0.2f} {:0.2f}\n'.format(utt_id, reco_id, mics[i], adj_start, adj_end))

for F in seg_Fs:
  F.close()
