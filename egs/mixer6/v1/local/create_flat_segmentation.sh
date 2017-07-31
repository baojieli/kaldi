#!/bin/bash

if [ $# -ne 1 ] && [ $# -ne 2 ]; then
  echo "Usage: $0 <data-dir> [<using-sox-trim>]"
  exit 1;
fi

data=$1
trim=$2

rm -f $data/{segments,utt2spk,spk2utt,spk2gender}

while read line; do
  sess_id=$(echo $line | awk '{print $1}')
  file=$(echo $line | sed 's/.* \([^ ]\+\.wav\).*/\1/g')
  if [ "$trim" -ne "true" ]; then
    len=$(soxi -D $file)
  else
    len=$(echo $line | awk -F'trim ' '{print $2}' | awk -F'[ =]' '{print $3-$1}')
  fi
  counter=0
  start_time=0
  cont=1
  while [ $cont -eq 1 ]; do
    end_time=$(echo "$start_time+15.0" | bc)
    cont=$(awk 'BEGIN {return_code=('"$end_time"' < '"$len"') ? 1 : 0; exit} END {exit return_code}'; echo $?)

    if [ $cont -eq 1 ]; then
      printf -v out "${sess_id}_%03d $sess_id $start_time $end_time" $counter
    else
      printf -v out "${sess_id}_%03d $sess_id $start_time $len" $counter
    fi
    echo $out >> $data/segments

    ((++counter))
    start_time=$(echo "$start_time+10.0" | bc)
  done
done < $data/wav.scp

cat $data/segments | awk '{print $1" "$2}' > $data/utt2spk
utils/fix_data_dir.sh $data
