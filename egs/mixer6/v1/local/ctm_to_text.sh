#!/bin/bash

if [ $# -ne "4" ]; then
  echo "Usage: $0 <ctm> <data_in> <script_folder> <data_out>"
  exit
fi

ctm=$1
data_in=$2
script_folder=$3
out=$4

seg=$data_in/segments

mkdir -p $out
cp $data_in/wav.scp $out
rm -f $out/{segments,text}

ids=$(cat $ctm | awk '{print $1}' | uniq)

for id in $ids; do
  script=$script_folder/$(ls $script_folder | grep $id)

  # Prepare ctm part for align-text
  grep -e "$id" $ctm | awk '{print $5}' > temp1.txt
  echo -n "utt" > temp2.txt
  while read line; do
    echo -n " $line" >> temp2.txt
  done < temp1.txt

  # Prepare sript part for align-text
  echo -n "utt" > temp3.txt
  while read line; do
    echo -n " $line" >> temp3.txt
  done < $script

  align-text ark:temp2.txt ark:temp3.txt ark,t:temp4.txt 2>/dev/null
  cat temp4.txt | cut -c 4- | sed 's/;/\n/g' | cut -c 2- > temp5.txt

  # prepare segments for id
  grep -e "$id" $ctm | awk '{print $3" "$4}' > temp6.txt
  wav=$(grep -e "$id" $data_in/wav.scp | sed 's/.* \([^ ]\+\.wav\).*/\1/g')
  local/ctm_scr_ali_to_seg.py $id $(soxi -D $wav) temp6.txt $script temp5.txt temp7.txt

  cat temp7.txt >> $out/segments
  cat temp7.txt | awk '{print $1}' > temp8.txt
  paste temp8.txt $script | sed 's/\t/ /g' >> $out/text
done

cat $out/segments | awk '{print $1" "substr($1,0,6)}' > $out/utt2spk
utils/fix_data_dir.sh $out

rm temp{1,2,3,4,5,6,7,8}.txt
