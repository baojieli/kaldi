#!/bin/bash

if [ $# -ne 2 ]; then
  echo "Usage:"
  echo "$0 <data_dir> <wav_dir>"
  echo "Extracts segments from data directory as wav files"
  exit
fi

dir_in=$1
dir_out=$2

mkdir -p $dir_out

rm -f $dir_in/sox.log
while read line; do
  id=$(echo "$line" | awk '{print $1}')
  reco_id=$(echo "$line" | awk '{print $2}')
  flac=$(grep -e "$reco_id" $dir_in/wav.scp | awk '{print $5}')
  comp_start=$(grep -e "$reco_id" $dir_in/wav.scp | awk '{print $12}')
  start_time=$(echo "$line" | awk -v cs=$comp_start '{print $3+cs}')
  end_time=$(echo "$line" | awk -v cs=$comp_start '{print $4+cs}')
  sox -t flac $flac -r 16k -t wav - trim $start_time =$end_time 2>> $dir_in/sox.log |\
    sox --norm -t wavpcm - $dir_out/${id}.wav &>> $dir_in/sox.log
done < $dir_in/segments
