#!/bin/bash 

# Copyright    2013  Daniel Povey
#              2017  Matthew Maciejewski
# Apache 2.0
# To be run from .. (one directory up from here)
# see ../run.sh for example

# Compute energy based VAD output 
# We do this in just one job; it's fast.
#

nj=2
cmd=run.pl
vad_config=conf/ed.conf

echo "$0 $@"  # Print the command line for logging

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;

if [ $# != 4 ]; then
   echo "Usage: $0 [options] <strong-data-dir> <weak-data-dir> <log-dir> <path-to-vad-dir>";
   echo "e.g.: $0 data/train exp/make_vad mfcc"
   echo " Options:"
   echo "  --vad-config <config-file>                       # config passed to compute-vad-energy"
   echo "  --nj <nj>                                        # number of parallel jobs"
   echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
   exit 1;
fi

data1=$1
data2=$2
logdir=$2
vaddir=$3

# make $vaddir an absolute pathname.
vaddir=`perl -e '($dir,$pwd)= @ARGV; if($dir!~m:^/:) { $dir = "$pwd/$dir"; } print $dir; ' $vaddir ${PWD}`

# use "name" as part of name of the archive.
name=`basename $data1`

mkdir -p $vaddir || exit 1;
mkdir -p $logdir || exit 1;


for f in $data1/feats.scp $data2/feats.scp "$vad_config"; do
  if [ ! -f $f ]; then
    echo "compute_energy_diarization.sh: no such file $f"
    exit 1;
  fi
done

utils/split_data.sh $data1 $nj || exit 1;
sdata1=$data1/split$nj;
utils/split_data.sh $data2 $nj || exit 1;
sdata2=$data2/split$nj;

$cmd JOB=1:$nj $logdir/vad_${name}.JOB.log \
  compute-energy-diarization --config=$vad_config scp:$sdata1/JOB/feats.scp scp:$sdata2/JOB/feats.scp \
      ark,scp:$vaddir/vad_${name}.JOB.ark,$vaddir/vad_${name}.JOB.scp || exit 1;

for ((n=1; n<=nj; n++)); do
  cat $vaddir/vad_${name}.$n.scp || exit 1;
done > $data1/vad.scp

nc=`cat $data1/vad.scp | wc -l` 
nu=`cat $data1/feats.scp | wc -l` 
if [ $nc -ne $nu ]; then
  echo "**Warning it seems not all of the speakers got VAD output ($nc != $nu);"
  echo "**validate_data_dir.sh will fail; you might want to use fix_data_dir.sh"
  [ $nc -eq 0 ] && exit 1;
fi


echo "Created Energy Diarization for $name"
