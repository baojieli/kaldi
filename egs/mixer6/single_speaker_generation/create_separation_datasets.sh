#!/bin/bash

set -e

stage=1

if [ $# -le 1 ]; then
  echo "Usage:"
  echo "$0 <mixer6-dir> <output-dir>"
  echo "This script creates takes the location of the Mixer 6 corpus and an"
  echo "output directory and uses the MERL WSJ-2mix scripts to make the analogous"
  echo "overlap datasets from Mixer6 CH02 and CH09, consisting of cv, tr, tt,"
  echo " and the 100k-mixture tr set."
  exit 1;
fi

corpus_dir=$1
out_dir=$2

command -v sox >/dev/null 2>&1 || { echo >&2 "Sox is required but is not installed. Exiting"; exit 1; }
command -v matlab >/dev/null 2>&1 || { echo >&2 "MATLAB is required but is not installed. Exiting"; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo >&2 "Unzip is required but is not installed. This is only used for extracting MERL scripts. Exiting"; exit 1; }

if [ $stage -le 1 ]; then
# Produce single-speaker wav files
  echo "*** Producing single-speaker wav files ***"
  for ch in 02 09; do
    local/mixer6_ch_single_speaker_data_prep.sh $corpus_dir $ch intv data/intv_CH${ch}_final

    mkdir -p data/single_spk_CH${ch}
    cp data/intv_CH${ch}_final/wav.scp data/single_spk_CH${ch}
    awk -F'[_ ]' -v ch=$ch '{print $4"_CH"ch"_"$1"_"$2"_"$3"_"$4"_"$5"_"$6" "$4"_CH"ch"_"$7"_"$8"_"$9"_"$10" "$11" "$12}' \
      data/intv_final/segments | sort > data/single_spk_CH${ch}/segments
    sed -e 's/ \([0-9]*\)_.*$/ \1/g' data/single_spk_CH${ch}/segments > data/single_spk_CH${ch}/utt2spk
    utils/fix_data_dir.sh data/single_spk_CH${ch}

    for subset in cv tr tt; do
      cp -r data/single_spk_CH${ch} data/single_spk_CH${ch}_${subset}
      utils/filter_scp.pl <(cat mixes/mix_2_spk_CH${ch}_${subset}* | awk -F'[/ .]' '{print $3; print $9}' | sort -u) \
        data/single_spk_CH${ch}/segments \
        > data/single_spk_CH${ch}_${subset}/segments
      utils/fix_data_dir.sh data/single_spk_CH${ch}_${subset}

      mkdir -p $out_dir/single_spk/$subset/CH${ch}
      echo " -> extracting CH${ch}_${subset}"
      local/data_dir_to_wav.sh data/single_spk_CH${ch}_${subset} $out_dir/single_spk/$subset/CH${ch}
    done
  done
  echo "done"
  echo ""
fi

if [ $stage -le 2 ]; then
# Prepare modified MERL scripts
  echo "*** Preparing modified MERL scripts ***"
  wget "http://www.merl.com/demos/deep-clustering/create-speaker-mixtures.zip"
  unzip create-speaker-mixtures.zip -d MERL_scripts

  sed -i -e 's/wsj0root/mx6root/g' MERL_scripts/create_wav_2speakers.m
  sed -i -e '48s/mix_2_spk/mixes\/mix_2_spk/g' MERL_scripts/create_wav_2speakers.m
  line21="data_type = {'CH02_tr','CH02_cv','CH02_tt','CH02_tr_100k','CH09_tr','CH09_cv','CH09_tt','CH09_tr_100k'};"
  line22="mx6root = '$out_dir/single_spk/';"
  line23="output_dir16k='$out_dir/mx6-mix/2speakers/wav16k';"
  line24="output_dir8k='$out_dir/mx6-mix/2speakers/wav8k';"
  line26="min_max = {'min'};"
  awk -v line21="$line21" -v line22="$line22" -v line23="$line23" -v line24="$line24" -v line26="$line26" \
    '{if (NR == 21) {print line21}
      else if (NR == 22) {print line22}
      else if (NR == 23) {print line23}
      else if (NR == 24) {print line24}
      else if (NR == 26) {print line26}
      else {print $0}}' \
    MERL_scripts/create_wav_2speakers.m > MERL_scripts/temp.m
  mv MERL_scripts/temp.m MERL_scripts/create_wav_2speakers.m
  echo "done"
  echo ""
fi

if [ $stage -le 3 ]; then
# Produce mixtures
  echo "*** Producing mixtures ***"
  matlab -nodisplay -nodesktop -nosplash -nojvm -r "addpath('MERL_scripts'); create_wav_2speakers; exit"
  mkdir -p MERL_scripts/intermediate_files
  mv mix_2_spk_min_* MERL_scripts/intermediate_files
  echo "done"
fi
