#!/usr/bin/env python

import sys
import os
import numpy as np
from scipy import spatial

def main():
  if len(sys.argv) != 4:
    print "Usage: "+sys.argv[0]+" <score-counts-file1> <score-counts-file2> <output>"
    exit()

  countsfile1 = sys.argv[1]
  countsfile2 = sys.argv[2]
  outfile = sys.argv[3]

  ids1 = []
  ids2 = []
  vecdict1 = {}
  vecdict2 = {}

  with open(countsfile1,'r') as countsF:
    for line in countsF:
      split = line.rstrip().split()
      ids1.append(split.pop(0))
      vecdict1[ids1[-1]] = np.array(split,dtype=float)
  with open(countsfile2,'r') as countsF:
    for line in countsF:
      split = line.rstrip().split()
      ids2.append(split.pop(0))
      vecdict2[ids2[-1]] = np.array(split,dtype=float)

  outF = open(outfile,'w')
  for i in range(len(ids1)):
    for j in range(len(ids2)):
      score = 1 - spatial.distance.cosine(vecdict1[ids1[i]],vecdict2[ids2[j]])
      if ids1[i][0:6] == ids2[j][0:6]:
        key = "target"
      else:
        key = "nontarget"
      outline = ids1[i]+' '+ids2[j]+' '+str(score)+' '+key+'\n'
      outF.write(outline)
  outF.close()

if __name__ == '__main__':
  main()
