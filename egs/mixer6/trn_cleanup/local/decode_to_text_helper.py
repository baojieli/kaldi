#!/usr/bin/env python

import sys

if not len(sys.argv) == 4:
  print "Usage: "+sys.argv[0]+" <segment-word-counts> <aligned-text> <script-text>"
  exit(0)

counts = []
with open(sys.argv[1],'r') as countF:
  for line in countF:
    split = line.rstrip().split()
    counts.append([split[0],int(split[1])])

scrF = open(sys.argv[3],'r')

ind_c = 0
outline = counts[ind_c][0]
alict = 0
with open(sys.argv[2],'r') as alignF:
  for alignline in alignF:
    split = alignline.rstrip().split()
#
    while alict >= counts[ind_c][1]:
      print(outline)
      ind_c = ind_c+1
      if ind_c == len(counts):
        exit()
      while counts[ind_c][1] == 0:
        print(counts[ind_c][0])
        ind_c = ind_c+1
        if ind_c == len(counts):
          exit()
      alict = 0
      outline = counts[ind_c][0]
#
    if not split[0] == "<eps>":
      alict = alict+1
    if not split[1] == "<eps>":
      outline = outline+" "+scrF.readline().rstrip()
#    if alict >= counts[ind_c][1]:
#      print(outline)
#      ind_c = ind_c+1
#      if ind_c == len(counts):
#        exit()
#      while counts[ind_c][1] == 0:
#        print(counts[ind_c][0])
#        ind_c = ind_c+1
#        if ind_c == len(counts):
#          exit()
#      alict = 0
#      outline = counts[ind_c][0]

if ind_c < len(counts):
  while counts[ind_c][1] == 0:
    print(counts[ind_c][0])
    ind_c = ind_c+1
