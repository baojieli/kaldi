#!/usr/bin/env python3

import sys

def main():
  num_in = len(sys.argv)-2
  if num_in <= 0:
    print("Usage: "+sys.argv[0]+" <spk-num-trn-out> <trn1> [<trn2> ...]")
    print("  converts a set of transcripts into a single transcript that")
    print("   lists the number of speakers per segment. The format for all")
    print("   files is:")
    print("     [start-time] [end-time] [label]")
    print("   where the label is the number of speakers in the output and")
    print("   can be anything for the input (or nothing).")
    exit(1)

  active_in = []
  files = []
  lines = []
  for i in range(num_in):
    active_in.append(i)
    files.append(open(sys.argv[i+2], 'r'))
    line = files[i].readline().split()
    lines.append(line[1::-1])

  seg_bounds = [[0.0, 0]] # array of pairs [time boundary, speaker number change]
  while active_in:
    # iterate through files for lowest index
    min_time = float("Inf")
    min_index = None
    for i in active_in:
      if float(lines[i][-1]) < min_time:
        min_time = float(lines[i][-1])
        min_index = i

    if len(lines[min_index]) == 2:  # this is a start time
      if seg_bounds[-1][0] == min_time:  # if boundary exists, increment num change
        seg_bounds[-1][1] += 1
      else:  # else add boundary with a spk num increment
        seg_bounds.append([min_time, 1])
      # remove this time mark
      lines[min_index].pop()

    else:  # this is an end time
      if seg_bounds[-1][0] == min_time:  # if boundary exists, decrement num change
        seg_bounds[-1][1] -= 1
      else:  # else add boundary with a spk num decrement
        seg_bounds.append([min_time, -1])
      # update lines array, update active inputs
      line = files[min_index].readline().split()
      if not line:
        active_in.remove(min_index)
        files[min_index].close()
      else:
        lines[min_index] = line[1::-1]

  file_out = open(sys.argv[1], 'w')
  num_spk = 0
  for bound in seg_bounds:
    if bound[1]:
      if num_spk == 0:
        file_out.write(str(bound[0])+' ')
      elif num_spk + bound[1] == 0:
        file_out.write(str(bound[0])+' '+str(num_spk)+'\n')
      else:
        file_out.write(str(bound[0])+' '+str(num_spk)+'\n'+str(bound[0])+' ')
      num_spk += bound[1]
  file_out.close()


if __name__ == '__main__':
  main()

