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

corpus_dir=/export/corpora5/LDC/LDC2013S03

if [ $stage -le 1 ]; then
### Prepare data directories for train, cross validation, test
  for ch in 02 09; do
    local/mixer6_ch_single_speaker_data_prep.sh $corpus_dir $ch intv data/intv_CH${ch}_final

    mkdir -p data/intv_CH${ch}_{tr,cv,tt}
    utils/filter_scp.pl -f 2 data/local/IDs_test.txt data/intv_CH${ch}_final/utt2spk \
      > data/intv_CH${ch}_tt/utt2spk
    utils/filter_scp.pl -f 2 data/local/IDs_cross_validation.txt data/intv_CH${ch}_final/utt2spk \
      > data/intv_CH${ch}_cv/utt2spk
    utils/filter_scp.pl --exclude -f 2 data/local/IDs_test.txt data/intv_CH${ch}_final/utt2spk |\
      utils/filter_scp.pl --exclude -f 2 data/local/IDs_cross_validation.txt \
      > data/intv_CH${ch}_tr/utt2spk

    for dset in tr cv tt; do
      utils/utt2spk_to_spk2utt.pl data/intv_CH${ch}_${dset}/utt2spk > data/intv_CH${ch}_${dset}/spk2utt
      utils/filter_scp.pl data/intv_CH${ch}_${dset}/utt2spk data/intv_CH${ch}_final/segments |\
        tee data/intv_CH${ch}_${dset}/segments | awk '{print $2}' | uniq > reco_list.tmp
      utils/filter_scp.pl reco_list.tmp data/intv_CH${ch}_final/wav.scp > data/intv_CH${ch}_${dset}/wav.scp
      rm -f reco_list.tmp

      utils/validate_data_dir.sh --no-feats --no-text data/intv_CH${ch}_${dset}
    done
  done
fi

if [ $stage -le 2 ]; then
### Prepare mix lists
  mkdir -p mixes
  for ch in 02 09; do
    # Create base filelists
    for dset in tr tt cv; do
      mkdir -p tmp_mix/$dset/CH$ch/
      awk -v ch=$ch -v dset=$dset '{print dset"/CH"ch"/"$1".wav"}' \
        data/intv_CH${ch}_${dset}/segments > tmp_mix/$dset/CH$ch/filelist.txt
    done

    # Create filelist for set speaker-balanced to WSJ0
    mkdir -p tmp_mix/tr_wsj-spk-bal/CH$ch/
    awk -v ch=$ch '{print "tr_wsj-spk-bal/CH"ch"/"$1".wav"}' \
      data/intv_CH${ch}_tr_wsj-spk-bal/segments > tmp_mix/tr_wsj-spk-bal/CH$ch/filelist.txt
  done

  # Create base mixture lists
  local/filelist_to_mixlist.py --target-mix-num 5000 tmp_mix/cv/CH02/filelist.txt \
    mixes/mix_2_spk_CH02_cv.txt
  local/filelist_to_mixlist.py --target-mix-num 3000 tmp_mix/tt/CH02/filelist.txt \
    mixes/mix_2_spk_CH02_tt.txt
  local/filelist_to_mixlist.py --target-mix-num 20000 tmp_mix/tr/CH02/filelist.txt \
    mixes/mix_2_spk_CH02_tr.txt

  # Create 100,000-mixture training set mixture list
  local/filelist_to_mixlist.py --target-mix-num 100000 tmp_mix/tr/CH02/filelist.txt \
    mixes/mix_2_spk_CH02_tr_100k.txt

  # Create WSJ0-speaker-balanced training set mixture list
  local/filelist_to_mixlist.py --target-mix-num 20000 tmp_mix/tr_wsj-spk-bal/CH02/filelist.txt \
    mixes/mix_2_spk_CH02_tr_wsj-spk-bal.txt

  for dset in tr tt cv tr_100k tr_wsj-spk-bal; do
    sed -e 's/CH02/CH09/g' mixes/mix_2_spk_CH02_${dset}.txt > mixes/mix_2_spk_CH09_${dset}.txt
  done
fi
