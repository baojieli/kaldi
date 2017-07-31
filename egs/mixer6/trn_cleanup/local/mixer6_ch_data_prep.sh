#!/bin/bash

if [ "$#" -ne 5 ]; then
  echo "Usage: $0 <transcript-dir> <channel> <component> <filelist> <data-dir-out>"
  exit
fi

trndir=$1
ch=$2
comp=$3
list=$4
datadir=$5

flacdir="/export/corpora5/LDC/LDC2013S03/mx6_speech/data/pcm_flac/CH$ch"

rm -rf $datadir
mkdir -p $datadir

while read line; do
  newF=$(echo $line | awk -F'.' '{print $1}')
  oldF=$(basename $(ls $flacdir/$(echo $line | awk -F'[_.]' '{print $2"_*_"$1"_CH'"$ch"'"}')*) | awk -F'_' '{print $1"_"$2"_"$3"_"$4}')

  ivline=$(grep -P "$oldF" /export/speakerphone/data/info/iv_components_final.csv)
  if [ "$comp" == "intv" ]; then
    t1=$(echo "$ivline" | awk -F',' '{print $4}')
    t2=$(echo "$ivline" | awk -F',' '{print $5}')
  elif [ "$comp" == "rdtr" ]; then
    t1=$(echo "$ivline" | awk -F',' '{print $6}')
    t2=$(echo "$ivline" | awk -F',' '{print $7}')
  elif [ "$comp" == "call" ]; then
    t1=$(echo "$ivline" | awk -F',' '{print $8}')
    t2=$(echo "$ivline" | awk -F',' '{print $9}')
  else
    echo "ERROR: invalid component: $comp"
    exit
  fi
  echo "$newF sox -t flac $(ls $flacdir/$oldF*) -r 8k -t wav - trim $t1 =$t2 |" >> $datadir/wav.scp

  if [ "$trndir" != "NONE" ]; then
    echo "test"
    cat $trndir/$newF.txt | tr '[:upper:]' '[:lower:]' | awk -v id="$newF" -F',' '{printf("%s_%03d %s\n", id, NR-1, $3)}' >> $datadir/text
    cat $trndir/$newF.txt | awk -v id="$newF" -F',' '{printf("%s_%03d %s %s %s\n", id, NR-1, id, $1, $2)}' >> $datadir/segments
  else
    echo "$t1 $t2" | awk -v id="$newF" '{printf("%s_%03d %s %s %s\n", id, 0, id, "0.0", $2-$1)}' >> $datadir/segments
  fi
done < $list

cat $datadir/segments | awk '{print $1" "$2}' > $datadir/utt2spk

utils/fix_data_dir.sh $datadir
