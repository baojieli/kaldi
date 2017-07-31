#!/usr/bin/env python

import sys
import os
from numpy import linalg

norm=1.5

def incrementDict(dictionary, key):
  if key in dictionary.keys():
    dictionary[key] = dictionary[key] + 1
  else:
    dictionary[key] = 1

def populateDict(trnfile):
  dictionary = {}
  with open(trnfile,'r') as trnF:
    for line in trnF:
      phoneline = line.rstrip().split(',')
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
  return dictionary
      

def main():
  if len(sys.argv) != 3:
    print "Usage: "+sys.argv[0]+" <trn1> <trn2>"
    exit()

  trn1 = sys.argv[1]
  trn2 = sys.argv[2]

  trn1dict = populateDict(trn1)
  trn2dict = populateDict(trn2)

  keys = list(set().union(trn1dict.keys(),trn2dict.keys()))
  vec = []

  for key in keys:
    if key in trn1dict.keys():
      if key in trn2dict.keys():
        vec.append(1.0*trn1dict[key]*trn2dict[key])
      else:
        vec.append(1.0*trn1dict[key])
    else:
      vec.append(1.0*trn2dict[key])

  print(linalg.norm(vec, norm))


if __name__ == '__main__':
  main()
