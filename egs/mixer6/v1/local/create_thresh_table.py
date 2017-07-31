#!/usr/bin/env python

import sys

score_file = sys.argv[1]
thresh_file = sys.argv[2]

table = [["null", 0, 0]]
i = 0
with open(score_file,'r') as sF:
  for line in sF:
    split = line.rstrip().split()
    if not split[0] == table[i][0]:
      table[i][0] = split[0]
      table.append(list(table[i]))
      i = i+1
    if split[1] == "1":
      table[i][2] = table[i][2]+1
    table[i][1] = table[i][1]+1
table[i][0] = "inf"

outF = open(thresh_file,'w')
for j in range(len(table)):
  if table[i][1]-table[j][1] > 0:
    false_pos = "{0:.2f}".format(1.0*(table[i][1]-table[j][1]-table[i][2]+table[j][2])/(table[i][1]-table[j][1]))
  else:
    false_pos = "0.00"
  if table[i][2] > 0:
    false_neg = "{0:.2f}".format(1.0*(table[j][2])/(table[i][2]))
  else:
    false_neg = "0.00"
  outline = "thresh: "+table[j][0]+"\tchecking: "+str(table[i][1]-table[j][1])+"\tfalse positives: "+false_pos+"\tmissed: "+str(table[j][2])+"\tfalse negatives: "+false_neg+"\n"
  outF.write(outline)
outF.close()
