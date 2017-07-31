#!/usr/bin/env python

import sys
import os
import os.path
import errno

threshold = float(sys.argv[3])
buff = 0.2

def main():
  if not len(sys.argv) == 5:
    print "Usage: "+sys.argv[0]+" <old-data-dir> <alignment-ctm> <max-seg-length> <new-data-dir>"
    exit()

  segfile = sys.argv[1]+"/segments"
  ctmfile = sys.argv[2]

  try:
    os.makedirs(sys.argv[4])
  except OSError as exc:
    if exc.errno == errno.EEXIST and os.path.isdir(sys.argv[4]):
      pass
    else:
      raise

  idlist = []
  segdict = {}
  ctmdict = {}

  ## Propagate structure of segments:
  ## uttid -> [[seg1start, seg1start], [seg2start, seg2end], ...]
  with open(segfile) as segF:
    for line in segF:
      split = line.rstrip().split()
      if split[1] not in segdict.keys():
        segdict[split[1]] = []
        idlist.append(split[1])
      segdict[split[1]].append([float(split[2]),float(split[3])])

  ## Propagate structure of ctm marks:
  ## uttid -> [[[seg1word1start, seg1word1end], [seg1word2start, seg1word2end], ...],
  ##           [[seg2word1start, seg2word1end], [seg2word2start, seg2word2end], ...],
  ##           ...]
  with open(ctmfile) as ctmF:
    for line in ctmF:
      split = line.rstrip().split()
      if split[0] not in ctmdict.keys():
        ctmdict[split[0]] = []
        for i in range(len(segdict[split[0]])):
          ctmdict[split[0]].append([])
        uttct = 0

      if float(split[2])+float(split[3]) > segdict[split[0]][uttct][0]:
        if float(split[2]) < segdict[split[0]][uttct][1]:
          ctmdict[split[0]][uttct].append([max(float(split[2]),segdict[split[0]][uttct][0]),min(float(split[2])+float(split[3]),segdict[split[0]][uttct][1])])
        else:
          if ctmdict[split[0]][uttct] == []:
            ctmdict[split[0]][uttct].append(segdict[split[0]][uttct])
          uttct = min(uttct+1, len(segdict[split[0]])-1)

#      print(segdict[split[0]])
#      print(uttct)
#      if float(split[2]) < segdict[split[0]][uttct][0] or float(split[2])+float(split[3]) > segdict[split[0]][uttct][1]:
#        if ctmdict[split[0]][uttct] == []:
#          ctmdict[split[0]][uttct].append(segdict[split[0]][uttct])
#        uttct = uttct+1
#      else:
#        if float(split[2]) > segdict[split[0]][uttct][1]:
#          uttct = uttct+1
#        ctmdict[split[0]][uttct].append([float(split[2]),float(split[2])+float(split[3])])

  ## Fill in empty ctm arrays
  for sessid in idlist:
    utt = len(segdict[sessid])-1
    while len(ctmdict[sessid][utt]) == 0:
      ctmdict[sessid][utt].append(segdict[sessid][utt])

  segOut = open(sys.argv[4]+'/segments','w')

  for sessid in idlist:
    newlines = [] # will be array of [[segstart,segend], ['word1','word2',...]]
    for utt in range(len(segdict[sessid])):
#      segdict[sessid][utt][0] = max(segdict[sessid][utt][0], ctmdict[sessid][utt][0][0]-0.3)
#      segdict[sessid][utt][1] = min(segdict[sessid][utt][1], ctmdict[sessid][utt][-1][1]+0.3)
      updateLines(newlines, segdict[sessid][utt], ctmdict[sessid][utt])
    ct = 0
    maxlen = segdict[sessid][-1][1]
    for line in newlines:
      segline = sessid+"_"+str(ct).zfill(3)+" "+sessid+" "+"{0:.2f}".format(line[0][0])+" "+"{0:.2f}".format(min(line[0][1]+0.3,maxlen))+"\n"
      segOut.write(segline)
      ct = ct+1

  segOut.close()

def updateLines(newlines, segarray, ctmarray):
  #####
  if len(ctmarray) > 0:
    segarray[0] = max(segarray[0], ctmarray[0][0]-buff)
    segarray[1] = min(segarray[1], ctmarray[-1][1]+buff)
  #####
  if len(ctmarray) <= 1 or segarray[1]-segarray[0] < threshold or ctmarray[-1][1]-ctmarray[0][0] < threshold:
    newlines.append([segarray])
  else:
    silgaps = []
    for i in range(len(ctmarray)-1):
      silgaps.append(ctmarray[i+1][0]-ctmarray[i][1])
    if max(silgaps) >= 0.2:
      index = silgaps.index(max(silgaps))
      time = (ctmarray[index+1][0]+ctmarray[index][1])/2
      if time < ctmarray[index][1]+buff:
        segarray1 = [segarray[0], time]
      else:
        segarray1 = [segarray[0], ctmarray[index][1]+buff]
      if time > ctmarray[index+1][0]-buff:
        segarray2 = [time, segarray[1]]
      else:
        segarray2 = [ctmarray[index+1][0]-buff, segarray[1]]
      ctmarray1 = ctmarray[:index+1]
      ctmarray2 = ctmarray[index+1:]
      updateLines(newlines, segarray1, ctmarray1)
      updateLines(newlines, segarray2, ctmarray2)
    else:
      print("Warning, was unable to split utterance")
      print(segarray)
      newlines.append([segarray])

if __name__ == '__main__':
  main()
