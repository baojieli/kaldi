#!/usr/bin/env python

import sys
import os
import os.path
import errno

threshold = float(sys.argv[3])

def main():
  if not len(sys.argv) == 5:
    print "Usage: "+sys.argv[0]+" <old-data-dir> <alignment-ctm> <max-seg-length> <new-data-dir>"
    exit()

  segfile = sys.argv[1]+"/segments"
  ctmfile = sys.argv[2]
  textfile = sys.argv[1]+"/text"

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
  textdict = {}

  ## Propagate structure of segments:
  ## uttid -> [[seg1start, seg1start], [seg2start, seg2end], ...]
  with open(segfile) as segF:
    for line in segF:
      split = line.rstrip().split()
      if split[1] not in segdict.keys():
        segdict[split[1]] = []
        idlist.append(split[1])
      segdict[split[1]].append([float(split[2]),float(split[3])])

  ## Propagate structure of text:
  ## uttid -> [['seg1word1', 'seg1word2', ...],
  ##           ['seg2word1', 'seg2word2', ...],
  ##           ...]
  with open(textfile) as textF:
    for line in textF:
      split = line.rstrip().split()
      idsplit = split[0].split('_')
      sessid = idsplit[0]
      for i in range(1,len(idsplit)-1):
        sessid = sessid+'_'+idsplit[i]
      if sessid not in textdict.keys():
        textdict[sessid] = []
      textarr = []
      for i in range(len(split)-1):
        textarr.append(split[i+1])
      textdict[sessid].append(textarr)

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
      if float(split[2]) < segdict[split[0]][uttct][0] or float(split[2])+float(split[3]) > segdict[split[0]][uttct][1]:
        if ctmdict[split[0]][uttct] == []:
          ctmdict[split[0]][uttct].append(segdict[split[0]][uttct])
          newtext = ''
          for i in range(len(textdict[split[0]][uttct])):
            newtext = newtext+textdict[split[0]][uttct][i]+' '
          textdict[split[0]][uttct] = [newtext.rstrip()]
        uttct = uttct+1
      ctmdict[split[0]][uttct].append([float(split[2]),float(split[2])+float(split[3])])
      if len(ctmdict[split[0]][uttct]) == len(textdict[split[0]][uttct]):
        uttct = uttct+1

  ## Fill in empty ctm arrays
  for sessid in idlist:
    utt = len(segdict[sessid])-1
    while len(ctmdict[sessid][utt]) == 0:
      ctmdict[sessid][utt].append(segdict[sessid][utt])
      newtext = ''
      for i in range(len(textdict[sessid][utt])):
        newtext = newtext+textdict[sessid][utt][i]+' '
      textdict[sessid][utt] = [newtext.rstrip()]

  segOut = open(sys.argv[4]+'/segments','w')
  textOut = open(sys.argv[4]+'/text','w')

  for sessid in idlist:
    newlines = [] # will be array of [[segstart,segend], ['word1','word2',...]]
    for utt in range(len(segdict[sessid])):
      updateLines(newlines, segdict[sessid][utt], ctmdict[sessid][utt], textdict[sessid][utt])
    ct = 0
    for line in newlines:
      segline = sessid+"_"+str(ct).zfill(3)+" "+sessid+" "+"{0:.2f}".format(line[0][0])+" "+"{0:.2f}".format(line[0][1])+"\n"
      segOut.write(segline)
      textline = sessid+"_"+str(ct).zfill(3)
      for word in line[1]:
        textline = textline+" "+word
      textline = textline+"\n"
      textOut.write(textline)
      ct = ct+1

  segOut.close()
  textOut.close()

def updateLines(newlines, segarray, ctmarray, textarray):
  if len(ctmarray) == 1 or segarray[1]-segarray[0] < threshold or ctmarray[-1][1]-ctmarray[0][0] < threshold:
    newlines.append([segarray, textarray])
  else:
    silgaps = []
    for i in range(len(ctmarray)-1):
      silgaps.append(ctmarray[i+1][0]-ctmarray[i][1])
    if max(silgaps) >= 0.1:
      index = silgaps.index(max(silgaps))
      time = (ctmarray[index+1][0]+ctmarray[index][1])/2
      segarray1 = [segarray[0], time]
      segarray2 = [time, segarray[1]]
      ctmarray1 = ctmarray[:index+1]
      ctmarray2 = ctmarray[index+1:]
      textarray1 = textarray[:index+1]
      textarray2 = textarray[index+1:]
      updateLines(newlines, segarray1, ctmarray1, textarray1)
      updateLines(newlines, segarray2, ctmarray2, textarray2)
    else:
      print("Warning, was unable to split utterance")
      newlines.append([segarray, textarray])

if __name__ == '__main__':
  main()
