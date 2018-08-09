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
  start_time=$(echo "$line" | awk '{print $3}')
  end_time=$(echo "$line" | awk '{print $4}')
  wav=$(grep -e "$reco_id" $dir_in/wav.scp | awk '{if (NF == 2) {print $2} else {print $3}}')
  if [ "$reco_id" == "S05_P14" ] || [ "$reco_id" == "S23_P54" ]; then
    channel=2
  else
    channel=1
  fi
  sox $wav -t wavpcm - trim $start_time =$end_time remix $channel 2>> $dir_in/sox.log |\
    sox --norm -t wavpcm - $dir_out/${id}.wav &>> $dir_in/sox.log
done < $dir_in/segments
