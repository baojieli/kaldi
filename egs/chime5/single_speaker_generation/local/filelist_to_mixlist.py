#!/usr/bin/env python3

"""This script takes a filelist in Kaldi segment-naming convention
and creates a speaker-mixture filelist for use with the MERL scripts
for generating the WSJ mixture dataset.

This is done in an intelligent manner to maximize the quality of
resulting dataset. The following criteria are used to pair recordings,
in rough order of priority:

  - We should never pair two recordings by the same speaker.

  - We should prioritize using utterances that have been used the
      least, i.e. if a recording has been used twice, we should
      prioritize using a recording that has been used only once in
      order to minimize utterance redundancy in the resulting mixture.

  - We should minimize the number of times an utterance is paired with
      utterances by the same speaker, i.e. we want diversity in
      paired speakers in a given utterance.

  - Utterances should be paired with utterances of similar length,
      as we want to minimize the amount of the corpus that is 'thrown
      away' when trimming the longer utterance of a pair to the length
      of the shorter utterance.

This script uses a greedy algorithm to pair utterances one-by-one subject
to the above constraints to produce a reasonable dataset.
"""

import argparse
import sys, os
import random
from operator import itemgetter


pair_dict = {}

def get_args():
  parser = argparse.ArgumentParser(
    description="""This script takes a list of files from a single speaker
    segmentation and produces a list of mixtures""")

  parser.add_argument("input_file", type=str,
                      help="Input list of wav files")
  parser.add_argument("output_file", type=str,
                      help="Output file of wav mixtures")
  parser.add_argument("--target-mix-num", type=int,
                      help="Number of mixtures to produce",
                      default=20000)
  parser.add_argument("--max-snr", type=float,
                      help="Max SNR to range up to",
                      default=2.5)
  parser.add_argument("--write-stats", type=bool,
                      help="Write per-utt usage stats",
                      default=False)

  args = parser.parse_args()
  return args

def find_nearest_in_list(utt_in, list_in, utt_to_valid_spk_dict, tgt_spk_ind):
# Given an utterance length, finds the element in the list that's the closest in length
  length = utt_in[1]
  invalid_utts = pair_dict[utt_in[0]]
  prev_dist = 10000
  dist = 9999
  max_ind = 0
  delta = 0
  index = 0
  while dist < prev_dist and index < len(list_in):
    if (list_in[index][0] not in invalid_utts) and (tgt_spk_ind == -1 or tgt_spk_ind in utt_to_valid_spk_dict[list_in[index][0]]):
      prev_dist = dist
      delta = index-max_ind
      max_ind = index
      dist = abs(length-list_in[index][1])
    index += 1
  return (max_ind-delta, prev_dist)


def main():
  args = get_args()

  # Generate list of speakers (and index is maintained across data structures)
  spk_list = []
  with open(args.input_file, 'r') as inF:
    for line in inF:
      spk = line.split('_')[-3]
      if spk not in spk_list:
        spk_list.append(spk)
  spk_list.sort()

  num_used_lists = [[]]
  for i in range(len(spk_list)):
    num_used_lists[0].append([])
  utt_to_valid_spk_dict = {}

  # Initialize data structures
  with open(args.input_file, 'r') as inF:
    for line in inF:
      utt = line.rstrip()
      spk = line.split('_')[-3]
      spk_ind = spk_list.index(spk)
      tmp_split = line.split('.')[-2].split('_')
      utt_len = int(tmp_split[-1])-int(tmp_split[-2])
      other_spks = list(range(len(spk_list)))
      del other_spks[spk_ind]

      num_used_lists[0][spk_ind].append((utt, utt_len))  # All utterances have been used 0 times
      utt_to_valid_spk_dict[utt] = other_spks  # All other speakers are valid
      pair_dict[utt] = []  # Nothing is paired

  # Sort speaker utterance lists in descending order by length
  for spk_ind in range(len(spk_list)):
    num_used_lists[0][spk_ind].sort(key=itemgetter(1),reverse=True)

  lines_written = 0
  outF = open(args.output_file, 'w')
  override_count = 0
  least_num_used = 0
  while lines_written < args.target_mix_num:
    # Find next utterance to work on
    max_len = 0
    while max_len == 0:
      max_len = 0
      max_spk_ind = 0
      for spk_ind in range(len(spk_list)):
        if num_used_lists[least_num_used][spk_ind]:
          if num_used_lists[least_num_used][spk_ind][0][1] > max_len:
            max_spk_ind = spk_ind
            max_len = num_used_lists[least_num_used][spk_ind][0][1]
      if max_len == 0: # We never found an utterance which means we have exhausted this tier
        least_num_used += 1

    # Find the nearest utterance in length that has been used the least and does not represent a previously-used speaker pair
    candidate = []
    cand_num_used = least_num_used
    override_spk = False
    while not candidate:
      if cand_num_used < len(num_used_lists): # Make sure we havent used up all valid utterances
        smallest_dist = 1000
        for other_spk_ind in utt_to_valid_spk_dict[num_used_lists[least_num_used][max_spk_ind][0][0]]:
          if override_spk:
            nearest = find_nearest_in_list(num_used_lists[least_num_used][max_spk_ind][0], num_used_lists[cand_num_used][other_spk_ind], utt_to_valid_spk_dict, -1)
          else:
            nearest = find_nearest_in_list(num_used_lists[least_num_used][max_spk_ind][0], num_used_lists[cand_num_used][other_spk_ind], utt_to_valid_spk_dict, max_spk_ind)
          if nearest[1] < smallest_dist:
            smallest_dist = nearest[1]
            candidate = [cand_num_used, other_spk_ind, nearest[0]]
        if not candidate: # We never found a candidate so we use more-used utterances
          cand_num_used += 1
      else: # There were no candidates so we remove the other used speaker restriction and start over
        override_count += 1
        other_spks = list(range(len(spk_list)))
        del other_spks[max_spk_ind]
        if utt_to_valid_spk_dict[num_used_lists[least_num_used][max_spk_ind][0][0]] == other_spks:
          if override_spk:
            print("Cannot find any valid pairing for "+num_used_lists[least_num_used][max_spk_ind][0][0])
            exit()
          else:
            override_spk = True
        utt_to_valid_spk_dict[num_used_lists[least_num_used][max_spk_ind][0][0]] = other_spks
        cand_num_used = least_num_used

    # Write the pairing and update our data structures
    SNR = random.uniform(0, args.max_snr)
    line_out = num_used_lists[least_num_used][max_spk_ind][0][0]+" "+str(SNR)+" "+ \
               num_used_lists[candidate[0]][candidate[1]][candidate[2]][0]+" "+str(-1.0*SNR)+"\n"
    outF.write(line_out)
    lines_written += 1

    pair_dict[num_used_lists[least_num_used][max_spk_ind][0][0]].append(num_used_lists[candidate[0]][candidate[1]][candidate[2]][0])
    pair_dict[num_used_lists[candidate[0]][candidate[1]][candidate[2]][0]].append(num_used_lists[least_num_used][max_spk_ind][0][0])

    utt_to_valid_spk_dict[num_used_lists[least_num_used][max_spk_ind][0][0]].remove(candidate[1])
    if not override_spk:
      utt_to_valid_spk_dict[num_used_lists[candidate[0]][candidate[1]][candidate[2]][0]].remove(max_spk_ind)

    # Move first utterance
    utt = num_used_lists[least_num_used][max_spk_ind].pop(0)
    inserted = False
    if least_num_used+1 == len(num_used_lists): # Reached a new tier of usage and need to add space
      num_used_lists.append([])
      for i in range(len(spk_list)):
        num_used_lists[-1].append([])
    i = 0
    while not inserted:
      if i == len(num_used_lists[least_num_used+1][max_spk_ind]):
        num_used_lists[least_num_used+1][max_spk_ind].append(utt)
        inserted = True
      elif utt[1] > num_used_lists[least_num_used+1][max_spk_ind][i][1]:
        num_used_lists[least_num_used+1][max_spk_ind].insert(i, utt)
        inserted = True
      i += 1

    # Move candidate utterance
    utt = num_used_lists[candidate[0]][candidate[1]].pop(candidate[2])
    inserted = False
    if candidate[0]+1 == len(num_used_lists): # Reached a new tier of usage and need to add space
      num_used_lists.append([])
      for i in range(len(spk_list)):
        num_used_lists[-1].append([])
    i = 0
    while not inserted:
      if i == len(num_used_lists[candidate[0]+1][candidate[1]]):
        num_used_lists[candidate[0]+1][candidate[1]].append(utt)
        inserted = True
      elif utt[1] > num_used_lists[candidate[0]+1][candidate[1]][i][1]:
        num_used_lists[candidate[0]+1][candidate[1]].insert(i, utt)
        inserted = True
      i += 1

  outF.close()
  if override_count > 0:
    print("Warning:")
    print(" Constraint of not pairing an utterance to multiple utterances")
    print(" by the same speaker was violated "+str(override_count)+" times")

  # Write how many times each utterance was used
  if args.write_stats:
    outF = open(args.output_file+'.stats', 'w')
    for i in range(len(num_used_lists)):
      for spk in num_used_lists[i]:
        for utt in spk:
          outF.write(utt[0]+' '+str(i)+'\n')
    outF.close()

if __name__ == '__main__':
  main()
