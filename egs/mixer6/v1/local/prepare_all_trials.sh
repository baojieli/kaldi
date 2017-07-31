#!/bin/bash

# Usage: prepare_all_trials.sh <datadir1> <datadir2> <trials-out>

datadir1=$1
datadir2=$2
trials=$3

echo "Preparing trials for $datadir1 x $datadir2"

rm -f $trials

if [ "$datadir1" == "$datadir2" ]; then
  len=$(cat $datadir1/wav.scp | wc -l)
  for id1 in $(cat $datadir1/wav.scp | awk '{print $1}'); do
    for id2 in $(tail -n $len $datadir2/wav.scp | awk '{print $1}'); do
      if [ "$(echo $id1 | awk -F'_' '{print $1}')" == "$(echo $id2 | awk -F'_' '{print $1}')" ]; then
        echo "$id1 $id2 target" >> $trials
      else
        echo "$id1 $id2 nontarget" >> $trials
      fi
    done
    len=$((len-1))
  done
else
  for id1 in $(cat $datadir1/wav.scp | awk '{print $1}'); do
    for id2 in $(cat $datadir2/wav.scp | awk '{print $1}'); do
      if [ "$(echo $id1 | awk -F'_' '{print $1}')" == "$(echo $id2 | awk -F'_' '{print $1}')" ]; then
        echo "$id1 $id2 target" >> $trials
      else
        echo "$id1 $id2 nontarget" >> $trials
      fi
    done
  done
fi
