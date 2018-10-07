#!/usr/bin/env python3

# Copyright  2018  Matthew Maciejewski
# Apache 2.0.

import argparse
import sys

sys.path.append('steps/libs')
import common as common_lib


def get_args():
  parser = argparse.ArgumentParser(
    description="""This merges shorter segments into longer""")

  parser.add_argument("segments_in", type=str,
                      help="Input segments file")
  parser.add_argument("segments_out", type=str,
                      help="Output segments file")

  parser.add_argument("--max_segment_length", type=float, default=7.0,
                      help="Maximum length for segments")
  parser.add_argument("--min_silence_length", type=float, default=0.35,
                      help="Silence length below which segments are merged")

  args = parser.parse_args()
  return args

def process_segments(segments, min_sil, max_seg):
  i = 0
  while i < len(segments)-1:
    if (segments[i+1][0]-segments[i][1] <= min_sil) and (segments[i+1][1]-segments[i][0] <= max_seg):
      segments[i][1] = segments[i+1][1]
      segments.pop(i+1)
    else:
      i = i+1

def write_segments(out_file, reco, segments):
  for seg in segments:
    print("{0}_{1:05d}_{2:05d} {0} {3:0.2f} {4:0.2f}".format(
      reco, round(seg[0]*100), round(seg[1]*100), float(seg[0]), float(seg[1])), file=out_file)

def main():
  args = get_args()

  seg_out_file = open(args.segments_out, 'w')

  prev_reco = ""
  new_segs = []
  with common_lib.smart_open(args.segments_in) as seg_in_file:
    for line in seg_in_file:
      seg, reco, start, end = line.strip().split()
      if not reco == prev_reco:
        process_segments(new_segs, args.min_silence_length, args.max_segment_length)
        write_segments(seg_out_file, prev_reco, new_segs)
        new_segs = []
      new_segs.append([float(start), float(end)])
      prev_reco = reco
    process_segments(new_segs, args.min_silence_length, args.max_segment_length)
    write_segments(seg_out_file, prev_reco, new_segs)

  seg_out_file.close()

if __name__ == '__main__':
  main()
