#!/usr/bin/env python

import sys

if not len(sys.argv) == 5:
  print("Usage: "+sys.argv[0]+" <ref_ctm> <hyp_ctm> <word> <similarity_threshold>")

  sys.exit(1)

ref_ctm = sys.argv[1]
hyp_ctm = sys.argv[2]
word = sys.argv[3]
sim_thresh = float(sys.argv[4]) # value 0 to 1

def check(times, interval, thresh):
  for i in range(len(times)):
    den = times[i][1]-times[i][0] + interval[1]-interval[0]

    if 2*(min(times[i][1],interval[1])-max(times[i][0],interval[0]))/den > thresh:
      return True

  return False

def compare(times1, times2, thresh):
  num = 0
  den = len(times1)

  for i in range(len(times1)):
    if check(times2, times1[i], thresh):
      num = num+1

  return (num, den)

ids = []
with open(ref_ctm,'r') as ref_file:
  for line in ref_file:
    split = line.split()
    if not split[0] in ids:
      ids.append(split[0])
with open(hyp_ctm,'r') as hyp_file:
  for line in hyp_file:
    split = line.split()
    if not split[0] in ids:
      ids.append(split[0])

pnum = 0
pden = 0
rnum = 0
rden = 0

for id in ids:

  ref_times = []
  with open(ref_ctm,'r') as ref_file:
    for line in ref_file:
      line = line.rstrip()
      split = line.split()
      if split[0] == id and split[4] == word:
        ref_times.append((float(split[2]),float(split[2])+float(split[3])))

  hyp_times = []
  with open(hyp_ctm,'r') as hyp_file:
    for line in hyp_file:
      line = line.rstrip()
      split = line.split()
      if split[0] == id and split[4] == word:
        hyp_times.append((float(split[2]),float(split[2])+float(split[3])))

  prec = compare(hyp_times, ref_times, sim_thresh)
  pnum = pnum+prec[0]
  pden = pden+prec[1]
  rec = compare(ref_times, hyp_times, sim_thresh)
  rnum = rnum+rec[0]
  rden = rden+rec[1]

if (not pden == 0) and (not rden == 0):
  print("word: "+word+"\tprecision: "+str(round(float(pnum)/pden,3))+" ("+str(pnum)+"/"+str(pden)+")\trecall: "+str(round(float(rnum)/rden,3))+" ("+str(rnum)+"/"+str(rden)+")")
elif pden == 0 and rden == 0:
  print("no instances of word: "+word)
elif pden == 0:
  print("word: "+word+"\tprecision: (no instances)\trecall: "+str(round(float(rnum)/rden,3))+" ("+str(rnum)+"/"+str(rden)+")")
elif rden == 0:
  print("word: "+word+"\tprecision: "+str(round(float(pnum)/pden,3))+" ("+str(pnum)+"/"+str(pden)+")\trecall: (no instances)")
