#!/bin/bash

full_ctm=$1
data=$2
new_data=$3

mkdir -p $new_data

rm -f $new_data/segments

for id in $(cat $full_ctm | awk -F'[ ]' '{print $1}' | uniq); do
  grep -e "$id" $full_ctm > ${id}.ctm
  endtime=$(soxi -D $(grep -e "$id" $data/wav.scp | sed 's/.* \([^ ]\+\.wav\).*/\1/g'))

  echo "working on $id"
  python local/flat_to_script/resegment_helper.py ${id}.ctm $endtime ${id}.segments

  cat ${id}.segments >> $new_data/segments
  rm ${id}.segments
  rm ${id}.ctm
done

cp $data/wav.scp $new_data
cat $new_data/segments | awk '{print $1" "$2}' > $new_data/utt2spk

utils/fix_data_dir.sh $new_data
