#!/bin/bash

max_sent=200

if [ $# -ne 4 ]; then
  echo "Usage: $0 <data-dir> <lang-dir> <ctm-file> <out-file>"
  exit 1;
fi
echo "$0 $@"

data=$1
lang=$2
ctm=$3
out=$4

rm -f $out
for id in $(cat $data/wav.scp | awk '{print $1}'); do
  max_time=$(grep -e "$id" $data/segments | head -n $max_sent | tail -n 1 | awk '{print $4}')
  (>&2 echo "Counting decoded phones for $id up to time $max_time")
  grep -e "$id" $ctm | awk -v t="$max_time" '{if ($3 <= t) {print $0}}' > sub_ctm.tmp
  echo -n "$id" >> $out
  while read line; do
    echo -n " $(grep -e " $line " sub_ctm.tmp | wc -l)" >> $out
  done < $lang/phones/nonsilence.txt
  echo "" >> $out
done
rm sub_ctm.tmp
