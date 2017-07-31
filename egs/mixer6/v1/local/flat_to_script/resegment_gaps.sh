#!/bin/bash

full_ctm=$1
data=$2
new_data=$3

mkdir -p $new_data

rm -f $new_data/segments

cat $full_ctm | awk -F'[. ]' '{printf("%s %s %03d.%02d %03d.%02d %s\n",$1,$2,$3,$4,$5,$6,$7)}' | sort > temp.ctm

for id in $(cat temp.ctm | awk -F'[ ]' '{print $1}' | uniq); do
  grep -e "$id" temp.ctm > ${id}.ctm
  endtime=$(soxi -D $(grep -e "$id" $data/wav.scp | awk '{print $2}'))

  echo "working on $id"
  python local/flat_to_script/resegment_gaps.py ${id}.ctm $endtime ${id}.segments

  cat ${id}.segments >> $new_data/segments
  rm ${id}.segments
  rm ${id}.ctm
done

rm temp.ctm

cp $data/wav.scp $new_data
cat $new_data/segments | awk '{print $1" "$2}' > $new_data/utt2spk

utils/fix_data_dir.sh $new_data
