#!/usr/bin/env python

import sys
import os
import numpy as np
from numpy import linalg

norm = 1.5
time_adjust_len = 2.0

def genFilenames():
  names = []
  directory = sys.argv[-1]
  arginds = range(1, len(sys.argv)-1, 2)
  for i in range(len(arginds)):
    name = ""
    for j in range(len(arginds)):
      filename = os.path.basename(sys.argv[arginds[j]])
      if j == i:
        name = filename.split('.')[0]+name
      else:
        name = name+'-'+filename.split('.')[0]
    names.append(directory+'/'+name+'.txt')
  return(names)

def incrementDict(dictionary, key):
  if key in dictionary.keys():
    dictionary[key] = dictionary[key] + 1
  else:
    dictionary[key] = 1

def populateDict(trnfile):
  tups = []
  with open(trnfile,'r') as trnF:
    for line in trnF:
      dictionary = {}
      phoneline = line.rstrip().split(',')
      length = float(phoneline[1])-float(phoneline[0])
      phones = phoneline[2].split()

      if len(phones) > 1:
        key = "<wb>_"+phones[0]+"_"+phones[1]
        incrementDict(dictionary, key)

        for i in range(1, len(phones)-1):
          key = phones[i-1]+'_'+phones[i]+'_'+phones[i+1]
          incrementDict(dictionary, key)

        key = phones[len(phones)-2]+'_'+phones[len(phones)-1]+"_<wb>"
        incrementDict(dictionary, key)
      elif len(phones) == 1:
        key = "<wb>_"+phones[0]+"_<wb>"
        incrementDict(dictionary, key)
      tups.append((dictionary, length))
  return tups

def scoreDicts(dict1, dict2):
  keys = list(set().union(dict1.keys(), dict2.keys()))
  vec = []

  for key in keys:
    if key in dict1.keys():
      if key in dict2.keys():
        vec.append(1.0*dict1[key]*dict2[key])
      else:
        vec.append(1.0*dict1[key])
    else:
      vec.append(1.0*dict2[key])

  return linalg.norm(vec, norm)

def scoreDictVec(dictionary, tupvec):
  scores = []
  for i in range(len(tupvec)):
    scores.append(scoreDicts(dictionary, tupvec[i][0]))
  return(np.mean(scores))

def main():
  if len(sys.argv)%2:
    print "Usage: "+sys.argv[0]+" <trn1> <len1> <trn2> <len2> [...] <outdir>"
    exit()

  filenames = genFilenames()

  tupvecs = []
  targlens = []
  for argind in range(1, len(sys.argv)-1, 2):
    trn = sys.argv[argind]
    tupvecs.append(populateDict(trn))
    targlens.append(float(sys.argv[argind+1]))

  scorevecs = []
  for i in range(len(tupvecs)):
    inds = range(len(tupvecs))
    inds.pop(i)
    scores = []
    for j in range(len(tupvecs[i])):
      sess_scores = []
      for k in inds:
        sess_scores.append(scoreDictVec(tupvecs[i][j][0], tupvecs[k]))
      score = linalg.norm(sess_scores, 2)
      scores.append(score/(tupvecs[i][j][1]+time_adjust_len))
    scorevecs.append(scores)

  trn_inds = []
  for i in range(len(scorevecs)):
    timecount = 0.0
    inds = []
    while timecount < targlens[i]:
      ind = np.argmax(scorevecs[i])
      inds.append(ind)
      scorevecs[i][ind] = -1
      timecount = timecount + tupvecs[i][ind][1]
    trn_inds.append(inds)

  for i in range(len(trn_inds)):
    text = [None]*len(trn_inds[i])
    line_num = 0
    with open(sys.argv[i*2+1]) as trnfile:
      for line in trnfile:
        if line_num in trn_inds[i]:
          text[trn_inds[i].index(line_num)] = line
        line_num = line_num+1
    outF = open(filenames[i], 'w')
    for line in text:
      outF.write(line)
    outF.close()

if __name__ == '__main__':
  main()
