#!/bin/bash

rm -f data/full_with_segments-hires/segments

for file in segments/*.txt; do
  sess_id=$(echo $file | awk -F'[/-]' '{print $2}')
  i=0
  while read line; do
    start=$(echo $line | awk -F'[,]' '{print $1}')
    end=$(echo $line | awk -F'[,]' '{print $2}')
    printf -v out "${sess_id}_%03d $sess_id $start $end\n" $i
    echo $out >> data/full_with_segments-hires/segments
    ((++i))
  done < $file;
done

exit

for file in $1/*.wav; do
  sess_id=$(echo $file | awk -F'[_.]' '{print $2}')
  echo "$sess_id $file" >> $2/wav.scp
  book="/home/mmaciej2/Singapore/info/books_txt/book$(echo $sess_id | sed 's/[0-9]//g' | tr '[:lower:]' '[:upper:]')-nopageturn.txt"
  i=0
  while read line; do
    printf -v out "${sess_id}_%02d $line\n" $i
    printf -v utt2spkout "${sess_id}_%02d $sess_id\n" $i
    echo $out >> $2/text
    echo $utt2spkout >> $2/utt2spk
    ((++i))
  done < $book;
done;

utils/fix_data_dir.sh $2
