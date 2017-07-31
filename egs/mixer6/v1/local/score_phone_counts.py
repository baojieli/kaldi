#!/usr/bin/env python

import sys
import os
import numpy as np
from scipy import spatial

def main():
  if len(sys.argv) != 3:
    print "Usage: "+sys.argv[0]+" <score-counts-file> <output>"
    exit()

  countsfile = sys.argv[1]
  outfile = sys.argv[2]

  ids = []
  vecdict = {}

  with open(countsfile,'r') as countsF:
    for line in countsF:
      split = line.rstrip().split()
      ids.append(split.pop(0))
      vecdict[ids[-1]] = np.array(split,dtype=float)

  outF = open(outfile,'w')
  for i in range(len(ids)):
    for j in range(i+1,len(ids)):
      score = 1 - spatial.distance.cosine(vecdict[ids[i]],vecdict[ids[j]])
      if ids[i][0:6] == ids[j][0:6]:
        key = "target"
      else:
        key = "nontarget"
      outline = ids[i]+' '+ids[j]+' '+str(score)+' '+key+'\n'
      outF.write(outline)
  outF.close()

if __name__ == '__main__':
  main()
