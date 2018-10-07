#!/bin/bash

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <corpus-dir> <channel> <component> <data-dir-out>"
  exit
fi

flacdir=$1/mx6_speech/data/pcm_flac/CH$2 # CLSP: /export/corpora5/LDC/LDC2013S03
ch=$2
comp=$3
datadir=$4

iv_comp=data/local/iv_components_final.csv

rm -rf $datadir
mkdir -p $datadir

if [ "$comp" == "intv" ]; then
  awk -F',' -v flacdir="$flacdir" -v ch=$ch '{print "CH"ch"_"$1" sox -t flac "flacdir"/"$1"_CH"ch".flac -r 16k -t wav - trim "$4" ="$5" |"}' $iv_comp | sort > $datadir/wav.scp
elif [ "$comp" == "rdtr" ]; then
  awk -F',' -v flacdir="$flacdir" -v ch=$ch '{print "CH"ch"_"$1" sox -t flac "flacdir"/"$1"_CH"ch".flac -r 16k -t wav - trim "$6" ="$7" |"}' $iv_comp | sort > $datadir/wav.scp
elif [ "$comp" == "call" ]; then
  awk -F',' -v flacdir="$flacdir" -v ch=$ch '{print "CH"ch"_"$1" sox -t flac "flacdir"/"$1"_CH"ch".flac -r 16k -t wav - trim "$8" ="$9" |"}' $iv_comp | sort > $datadir/wav.scp
else
  echo "ERROR: invalid component: $comp"
  exit
fi
sed -i -e 's/^\([^ ]*\)_\([0-9]*\) /\2_\1_\2 /g' $datadir/wav.scp

awk -F'[ _]' -v ch=$ch '{print $4"_CH"ch"_"$1"_"$2"_"$3"_"$4"_"$5"_"$6" "$4"_CH"ch"_"$7"_"$8"_"$9"_"$10" "$11" "$12}' \
  data/${comp}_final/segments > $datadir/segments
awk -v ch=$ch '{print $2"_CH"ch"_"$1" "$2}' data/${comp}_final/utt2spk > $datadir/utt2spk
utils/utt2spk_to_spk2utt.pl $datadir/utt2spk > $datadir/spk2utt

utils/fix_data_dir.sh $datadir
