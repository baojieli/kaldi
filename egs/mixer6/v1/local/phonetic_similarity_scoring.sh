#!/bin/bash

if [ $# != 5 ]; then
  echo "Usage: $0 <enroll-transcript-dir> <test-transcript-dir> <trials> <scoring-script> <scoring-out>"
  exit
fi

echo $@

dir1=$1
dir2=$2
trials=$3
script=$4
out=$5

rm -f $out

while read line; do
  tr1=$(echo $line | cut -d' ' -f1)
  tr2=$(echo $line | cut -d' ' -f2)
  echo "$tr1 $tr2 $($script $dir1/$tr1.txt $dir2/$tr2.txt)" >> $out
done < $trials
