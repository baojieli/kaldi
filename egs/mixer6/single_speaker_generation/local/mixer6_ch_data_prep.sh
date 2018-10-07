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
  awk -F',' -v flacdir="$flacdir" -v ch=$ch '{print $1" sox -t flac "flacdir"/"$1"_CH"ch".flac -r 16k -t wav - trim "$4" ="$5" |"}' $iv_comp | sort > $datadir/wav.scp
elif [ "$comp" == "rdtr" ]; then
  awk -F',' -v flacdir="$flacdir" -v ch=$ch '{print $1" sox -t flac "flacdir"/"$1"_CH"ch".flac -r 16k -t wav - trim "$6" ="$7" |"}' $iv_comp | sort > $datadir/wav.scp
elif [ "$comp" == "call" ]; then
  awk -F',' -v flacdir="$flacdir" -v ch=$ch '{print $1" sox -t flac "flacdir"/"$1"_CH"ch".flac -r 16k -t wav - trim "$8" ="$9" |"}' $iv_comp | sort > $datadir/wav.scp
else
  echo "ERROR: invalid component: $comp"
  exit
fi

awk '{print $1" "$1}' $datadir/wav.scp | tee $datadir/utt2spk > $datadir/spk2utt

utils/fix_data_dir.sh $datadir
