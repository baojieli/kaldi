#!/usr/bin/env python

import sys

ctm = sys.argv[1]
script = sys.argv[2]
ali = sys.argv[3]
outfile = sys.argv[4]

ali_file = open(ali,'r')
line = ali_file.readline()
line = line.rstrip()
line = line[2:]

pairs = line.split(";")
inds = [[],[]]
ctm_ctr = 0
script_ctr = 0
for pair in pairs:
  pair = pair.split()
  if pair[0] == "<eps>":
    inds[0].append("NULL")
  else:
    inds[0].append(ctm_ctr)
    ctm_ctr = ctm_ctr + 1
  if pair[1] == "<eps>":
    inds[1].append("NULL")
  else:
    inds[1].append(script_ctr)
    script_ctr = script_ctr + 1

scr_to_ctm = {}
for i in range(len(inds[1])):
  if not inds[1][i] == "NULL":
    ind = inds[0][i]
    j = 1
    while ind == "NULL":
      ind = inds[0][i-j]
      j = j+1
    scr_to_ctm[inds[1][i]] = ind

#print scr_to_ctm

ctm_ct = 0
ctm_times = []
with open(ctm,'r') as ctm_file:
  for line in ctm_file:
    split = line.split()
    ctm_times.append([split[2], str(float(split[2])+float(split[3]))])

ctm_to_segtimes = [[ctm_times[0][0], str( (float(ctm_times[0][1])+float(ctm_times[1][0]))/2 )]]
for i in range(1,len(ctm_times)-1):
  ctm_to_segtimes.append([ctm_to_segtimes[-1][1],str((float(ctm_times[i][1])+float(ctm_times[i+1][0]))/2)])
ctm_to_segtimes.append([ctm_to_segtimes[-1][1],ctm_times[-1][1]])

#print ctm_to_segtimes[615]
#print ctm_to_segtimes[616]
#print ctm_to_segtimes

outF = open(outfile,'w')
scr_ind = 0
split = ctm.split('.')
sess = split[0]
utt_num = 0
with open(script,'r') as script_file:
  for line in script_file:
    start_time = ctm_to_segtimes[scr_to_ctm[scr_ind]][0]
    scr_ind = scr_ind + len(line.split())
    end_time = ctm_to_segtimes[scr_to_ctm[scr_ind-1]][1]
#    print "start_time: "+str(start_time)+" end_time: "+str(end_time)+" and next start should be: "+str(ctm_to_segtimes[scr_to_ctm[scr_ind]][0])
    outline = sess+"_"+str(utt_num).zfill(2)+" "+sess+" "+start_time+" "+end_time+" "+line
    outF.write(outline)
    utt_num = utt_num+1
outF.close
