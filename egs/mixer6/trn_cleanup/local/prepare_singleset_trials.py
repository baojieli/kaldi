#!/usr/bin/env python

import sys

datadir = sys.argv[1]

wavF = open(datadir+'/wav.scp','r')
lines = wavF.readlines()

trialsF = open(datadir+'/trials','w')

oldid = ''
for i in range(len(lines)):
  sess1 = lines[i].split()[0]
  id1 = lines[i].split('_')[0]
  if not id1 == oldid:
    for j in range(len(lines)):
      sess2 = lines[j].split()[0]
      id2 = lines[j].split('_')[0]
      if id1 == id2:
        out = id1+' '+sess2+' '+'target\n'
      else:
        out = id1+' '+sess2+' '+'nontarget\n'
      trialsF.write(out)
    oldid = id1

wavF.close()
trialsF.close()
