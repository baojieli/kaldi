#!/bin/bash

wavdir=$1
list=$2
datadir=$3

mkdir -p $datadir

ls $wavdir | grep "wav" | awk -v dir="$wavdir" -F'.' '{print $1" sox "dir"/"$1".wav -r 8k -t wav -|"}' > temp
cat $list | awk -F'.' '{print $1}' | grep -f - temp > $datadir/wav.scp
rm temp

cat $datadir/wav.scp | awk '{print substr($1,1,6)" "tolower(substr($1,23,1))}' > $datadir/spk2gender

cat $datadir/wav.scp | awk '{print $1" "substr($1,1,6)}' > $datadir/utt2spk

utils/fix_data_dir.sh $datadir
