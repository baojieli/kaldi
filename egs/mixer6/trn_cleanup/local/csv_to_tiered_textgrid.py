#!/usr/bin/env python

import sys

if not len(sys.argv) == 4:
  print "Takes three arguments: <csv-file> <wav-duration> <out-texgrid>"
  print "csv is of format: start,dur,err,text"
  exit(0)

threshes = [0.8, 0.5, 0, -1]

outF = open(sys.argv[3],'w')

outline = 'File type = "ooTextFile"\nObject class = "TextGrid"\n\nxmin = 0\nxmax = '+sys.argv[2]+'\ntiers? <exists>\nsize = 4\nitem []:\n'
outF.write(outline)

data = []
ct = 0
with open(sys.argv[1],'r') as csvF:
  for line in csvF:
    line = line.rstrip()
    split = line.split(',')
    data.append([float(split[0]),float(split[0])+float(split[1]),float(split[2]),"u"+str(ct).zfill(3)+' '+split[3]])
    ct = ct+1

#if not data[0][0] == 0:
#  data.insert(0,[0, data[0][0], 0.0, ""])
#if not data[-1][1] == float(sys.argv[2]):
#  data.append([data[-1][1], float(sys.argv[2]), 0.0, ""])

i = 0
while i+1 < len(data):
  if data[i][1] > data[i+1][0]:
    mean = (data[i][1] + data[i+1][0])/2
    data[i][1] = mean
    data[i+1][0] = mean
    data[i][2] = 1.0
    data[i+1][2] = 1.0
#  if abs(data[i][1] - data[i+1][0]) > 0.09:
#    data.insert(i+1,[data[i][1],data[i+1][0],0.0,""])
  i = i+1
###

for th_i in range(len(threshes)):

  subdata = []
  for i in range(len(data)-1,-1,-1):
    if data[i][2] > threshes[th_i]:
      subdata.insert(0, data.pop(i))

  if len(subdata) > 0:
    if not subdata[0][0] == 0:
      subdata.insert(0,[0, subdata[0][0], 0.0, ""])
    if not subdata[-1][1] == float(sys.argv[2]):
      subdata.append([subdata[-1][1], float(sys.argv[2]), 0.0, ""])
  else:
    subdata.append([0, float(sys.argv[2]), 0.0, ""])

  i = 0
  while i+1 < len(data):
    if abs(data[i][1] - data[i+1][0]) > 0.09:
      data.insert(i+1,[data[i][1],data[i+1][0],0.0,""])
    i = i+1

  newline = '  item ['+str(th_i+1)+']:\n    class = "IntervalTier"\n    name = "words"\n    xmin = 0\n    xmax = '+sys.argv[2]+'\n    intervals: size = '+str(len(subdata))+'\n'
  outF.write(newline)

  for i in range(len(subdata)):
    outline = '    intervals ['+str(i+1)+']:\n      xmin = '+str(subdata[i][0])+'\n      xmax = '+str(subdata[i][1])+'\n      text = "'+subdata[i][3]+'"\n'
    outF.write(outline)

###

outF.close()
