#!/bin/bash

if [ $# -lt "3" ]; then
  echo "Usage: $0 <ref_ctm> <hyp_ctm> <word1> <word2> ..."
  exit
fi

ref_ctm=$1
hyp_ctm=$2
shift
shift
words=${@}

ref_ids=$(cat $ref_ctm | awk '{print $1}' | uniq)
hyp_ids=$(cat $hyp_ctm | awk '{print $1}' | uniq)

rm -f {hyp,ref}.tmp
for id in $ref_ids; do
  grep -e "$id" $hyp_ctm >> hyp.tmp
done
for id in $hyp_ids; do
  grep -e "$id" $ref_ctm >> ref.tmp
done

for word in $words; do
  local/compute_precision_recall.py ref.tmp hyp.tmp "$word" 0.75
done

rm -f {hyp,ref}.tmp
