#!/bin/bash
#
# Copyright  2017  Johns Hopkins University
# Apache 2.0
#

# Begin configuration section.
stage=1
# End configuration section
. ./utils/parse_options.sh

. ./cmd.sh
. ./path.sh


set -e # exit on error

if [ $stage -le 1 ]; then
  for dset in dev train; do
    mkdir -p tmp_mix/$dset/U01
    awk -v mic=U01 -v dset=$dset '{print dset"/"mic"/"$1".wav"}' \
      data/${dset}_final/U01/segments > tmp_mix/$dset/U01/filelist.txt
  done

  mkdir -p mixes
  local/filelist_to_mixlist.py --target-mix-num 5000 tmp_mix/dev/U01/filelist.txt \
    mixes/mix_2_spk_U01_dev.txt
  local/filelist_to_mixlist.py --target-mix-num 20000 tmp_mix/train/U01/filelist.txt \
    mixes/mix_2_spk_U01_train.txt
fi

if [ $stage -le 2 ]; then
  rm -f U01_to_close_talking_map.txt
  for dset in dev train; do
    grep -e "U01" data/${dset}_final/utt_equivalences.txt |\
      awk '{for(i=1; i<=NF; i++){if(substr($i,5,3)=="U01"){print $i}}}' > U01_utterances.tmp
    grep -e "U01" data/${dset}_final/utt_equivalences.txt |\
      awk '{for(i=1; i<=NF; i++){spk=substr($i,9,3); mic=substr($i,5,3); if(spk=="P14" && substr($i,1,3)=="S05"){if(mic=="P15"){print $i}} else if(spk=="P54" && substr($i,1,3)=="S23"){if(mic=="P56"){print $i}} else {if(mic==spk){print $i}}}}' > close_talking_utterances.tmp
    paste -d' ' U01_utterances.tmp close_talking_utterances.tmp >> U01_to_close_talking_map.txt

    sed -e "s/${dset}\/U01\///g;s/\.wav//g" mixes/mix_2_spk_U01_${dset}.txt |\
      utils/apply_map.pl -f 1 U01_to_close_talking_map.txt |\
      utils/apply_map.pl -f 3 U01_to_close_talking_map.txt |\
      awk -v dset=$dset '{print dset"/close_talking/"$1".wav "$2" "dset"/close_talking/"$3".wav "$4}' \
      > mixes/mix_2_spk_close_talking_${dset}.txt
  done
fi
