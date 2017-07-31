#!/bin/bash

dir=local/flat_to_script

data=$1
full_ctm=$2
script_folder=$3
data_new=$4

. ./path.sh

mkdir -p $data_new
rm -f $data_new/segments

for id in $(cat $full_ctm | awk -F'[ ]' '{print $1}' | uniq); do
  script=$script_folder/$(echo "$id" | sed -e 's/[0-9]//g').txt
  grep -e "$id" $full_ctm > ${id}.ctm

  sed -e 's/\./ /g' ${id}.ctm | awk '{print $3" "$4" "$7" "NR}' | sort -k1,1n -k2,2n > temp1.ctm
  python $dir/create_line_pairs.py temp1.ctm lines.txt
  sed -e "$(cat lines.txt)" ${id}.ctm > ${id}.fixed.ctm

  echo 'id' | cat - ${id}.fixed.ctm > temp.txt
  cut -d ' ' -f 5 temp.txt | tr '\n' ' ' > tempA.txt
  echo 'id' | cat - $script > temp.txt
  cat temp.txt | tr '\n' ' ' > tempB.txt
  align-text ark:tempA.txt ark:tempB.txt ark,t:tempC.txt

  python $dir/ctm_script_align_helper.py ${id}.fixed.ctm $script tempC.txt segments_$id
  endtime=$(soxi -D $(grep -e "$id" $data/wav.scp | awk '{print $2}'))
  python $dir/extend_segments.py 3 segments_$id $endtime >> $data_new/segments_text

  rm {${id}.ctm,temp1.ctm,lines.txt,${id}.fixed.ctm,temp.txt,tempA.txt,tempB.txt,tempC.txt,segments_$id}
done

cut -d' ' -f1,5- $data_new/segments_text > $data_new/text
cut -d' ' -f1-4 $data_new/segments_text > $data_new/segments
rm $data_new/segments_text

cp $data/wav.scp $data_new
cut -d' ' -f1-2 $data_new/segments > $data_new/utt2spk
utils/fix_data_dir.sh $data_new
