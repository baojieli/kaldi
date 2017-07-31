#!/bin/bash

if [ $# != 2 ]; then
  echo "Usage: $0 <blip-wav-folder> <data-dir>"
  exit
fi

mkdir -p $2
mv $2/{wav.scp,spk2utt,utt2spk,text} $2/.backup/ 2>/dev/null

for file in $1/*.wav; do
  sess_id=$(echo $file | awk -F'[_.]' '{print $2}')
  echo "$sess_id $file" >> $2/wav.scp
  echo "$sess_id $sess_id" >> $2/utt2spk
done;

utils/fix_data_dir.sh $2
