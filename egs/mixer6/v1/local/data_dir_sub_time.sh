#!/bin/bash

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <data-dir-in> <target-dur> <data-dir-out>"
  exit
fi

indir=$1
targtime=$2
outdir=$3

mkdir -p $outdir
cp $indir/wav.scp $outdir/wav.scp

cat $indir/segments | awk -v t="$targtime" 'BEGIN {oid="null"; time=0.0; pr=1} {if(pr){print $0}; if(time+$4-$3 > t){pr=0}; if(oid != $2){time=0.0; pr=1}; time=time+$4-$3; oid=$2}' > $outdir/segments

cat $outdir/segments | awk '{print $1" "$2}' > $outdir/utt2spk

utils/fix_data_dir.sh $outdir
