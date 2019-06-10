#!/bin/bash

set -e

stage=1

if [ $# -le 1 ]; then
  echo "Usage:"
  echo "$0 <chime5-dir> <output-dir>"
  echo "This script creates takes the location of the CHiME-5 corpus and an"
  echo "output directory and uses the MERL WSJ-2mix scripts to make the analogous"
  echo "overlap datasets from CHiME-5 near and far-field, consisting of the"
  echo "train and dev splits."
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

  for mic in close_talking U01; do
    for subset in dev train; do
      mkdir -p data/${mic}_${subset}
      awk -F'[ /]' '{print $3; print $7}' mixes/mix_2_spk_${mic}_${subset}.txt | sort -u |\
        awk -F'[-_.]' '{printf("%s-%s_%s_%s_%s %s-%s %0.2f %0.2f\n", $1, $2, $3, $4, $5, $1, $3, $4/100, $5/100)}' \
        > data/${mic}_${subset}/segments
      cut -d' ' -f2 data/${mic}_${subset}/segments | sort -u | \
        awk -F'-' -v dir="$corpus_dir" -v subset="$subset" -v mic="$mic" \
          '{if ($2 == "U01")
              {print $1"-"$2" "dir"/audio/"subset"/"$1"_"$2".CH1.wav"}
            else if (($1 == "S05") && ($2 == "P14"))
              {print $1"-"$2" "dir"/audio/"subset"/S05_P15.wav"}
            else if (($1 == "S23") && ($2 == "P54"))
              {print $1"-"$2" "dir"/audio/"subset"/S23_P56.wav"}
            else
              {print $1"-"$2" "dir"/audio/"subset"/"$1"_"$2".wav"}}' \
        > data/${mic}_${subset}/wav.scp

      mkdir -p $out_dir/single_spk/${subset}/${mic}
      echo " -> extracting ${mic}_${subset}"
      local/data_dir_to_wav.sh data/${mic}_${subset} $out_dir/single_spk/${subset}/${mic}
    done
  done
fi

if [ $stage -le 2 ]; then
# Prepare modified MERL scripts
  echo "*** Preparing modified MERL scripts ***"
  wget "http://www.merl.com/demos/deep-clustering/create-speaker-mixtures.zip"
  unzip create-speaker-mixtures.zip -d MERL_scripts

  sed -i -e 's/wsj0root/ch5root/g' MERL_scripts/create_wav_2speakers.m
  sed -i -e '48s/mix_2_spk/mixes\/mix_2_spk/g' MERL_scripts/create_wav_2speakers.m
  line21="data_type = {'CH02_tr','CH02_cv','CH02_tt','CH02_tr_100k','CH09_tr','CH09_cv','CH09_tt','CH09_tr_100k'};"
  line21="data_type = {'close_talking_dev','close_talking_train','U01_dev','U01_train'};"
  line22="ch5root = '$out_dir/single_spk/';"
  line23="output_dir16k='$out_dir/ch5-mix/2speakers/wav16k';"
  line24="output_dir8k='$out_dir/ch5-mix/2speakers/wav8k';"
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
