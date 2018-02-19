#!/bin/bash
# Copyright 2017-2018  David Snyder
#           2017-2018  Matthew Maciejewski
# Apache 2.0.

. ./cmd.sh
. ./path.sh
set -e
mfccdir=`pwd`/mfcc
vaddir=`pwd`/mfcc
stage=0
sad_stage=0

sad_dir=models/sad/stock
ivector_dir=models/ivector/stock
xvector_dir=
output_name="default"

train_sets="train"
test_sets="test"

if [ ! -z "$sad_dir" ]; then sad_suffix="_sad"; fi

# Prepare datasets
if [ $stage -le 0 ]; then
  # Prepare datasets for training and evaluation
  echo "Nothing here yet"
fi

# Speech Activity Detection Segmentation
if [ $stage -le 1 ] && [ ! -z "$sad_dir" ]; then
  for name in $test_sets; do ##### Might want to add train_sets if they do not have segmentation
    nf=$(cat data/$mic/$name/wav.scp | wc -l)
    steps/segmentation/detect_speech_activity.sh \
      --extra-left-context 70 --extra-right-context 0 --frames-per-chunk 150 \
      --extra-left-context-initial 0 --extra-right-context-final 0 \
      --nj $(($nf<40?$nf:40)) --acwt 0.3 --stage $sad_stage \
      data/$name $sad_dir mfcc_hires_bp exp/sad_segmentation_$name \
      data/${name}${sad_suffix}
  done
fi

if [ ! -z "$sad_dir" ]; then sad_suffix=${sad_suffix}_seg; fi

# Prepare features
if [ $stage -le 2 ]; then
  for name in $train_sets; do
    steps/make_mfcc.sh --mfcc-config conf/mfcc_8kHz.conf --nj 40 \
      --cmd "$train_cmd" --write-utt2num-frames true \
      data/$name exp/make_mfcc $mfccdir
    utils/fix_data_dir.sh data/$name

    nf=$(cat data/$name/wav.scp | wc -l)
    sid/compute_vad_decision.sh --nj $(($nf<40?$nf:40)) --cmd "$train_cmd" \
      data/$name exp/make_vad $vaddir
    utils/fix_data_dir.sh data/$name
  done

  for name in $test_sets; do
    name=${name}${sad_suffix}
    steps/make_mfcc.sh --mfcc-config conf/mfcc_8kHz.conf --nj 40 \
      --cmd "$train_cmd" --write-utt2num-frames true \
      data/$name exp/make_mfcc $mfccdir
    utils/fix_data_dir.sh data/$name

    nf=$(cat data/$name/wav.scp | wc -l)
    sid/compute_vad_decision.sh --nj $(($nf<40?$nf:40)) --cmd "$train_cmd" \
      data/$name exp/make_vad $vaddir
    utils/fix_data_dir.sh data/$name
  done

#  For PLDA training data that does not have segmentation, segmentation needs
#    to be created. This uses the simple energy VAD but we maybe should use
#    a better SAD since our training data may not be as clean.
#
#  # Create segments for ivector extraction for PLDA training data.
#  echo "0.01" > data/sre/frame_shift
#  diarization/vad_to_segments.sh --nj 40 --cmd "$train_cmd" \
#    data/sre data/sre_segmented
fi

# Extract i-vectors
if [ $stage -le 3 ]; then
  for name in $train_sets; do
    nf=$(cat data/$name/wav.scp | wc -l)
    diarization/extract_ivectors.sh --cmd "$train_cmd --mem 25G" \
      --nj $(($nf<40?$nf:40)) --window 3.0 --period 10.0 --min-segment 1.5 \
      --apply-cmn false --hard-min true $ivector_dir data/$name \
      exp/ivectors_$name
  done

  for name in $test_sets; do
    name=${name}${sad_suffix}
    nf=$(cat data/$name/wav.scp | wc -l)
    diarization/extract_ivectors.sh --cmd "$train_cmd --mem 20G" \
      --nj $(($nf<40?$nf:40)) --window 1.5 --period 0.75 --apply-cmn false \
      --min-segment 0.5 $ivector_dir data/$name exp/ivectors_$name
  done
fi

# Train PLDA models  ##### note: this is whitening using the test data
if [ $stage -le 4 ]; then
  for name in $test_sets; do
    name=${name}${sad_suffix}

    # Prepare PLDA training data
    mkdir -p exp/ivectors_$name/log
    for file in ivector.scp spk2utt; do
      rm -f exp/ivectors_$name/log/$file
      for train_name in $train_sets; do
        cat exp/ivectors_$train_name/$file >> exp/ivectors_$name/log/$file
      done
      sort exp/ivectors_$name/log/$file -o exp/ivectors_$name/log/$file
    done

    # Train PLDA
    "$train_cmd" exp/ivectors_$name/log/plda.log \
      ivector-compute-plda ark:exp/ivectors_$name/log/spk2utt \
        "ark:ivector-subtract-global-mean \
        scp:exp/ivectors_$name/log/ivector.scp ark:- \
        | transform-vec exp/ivectors_$name/transform.mat ark:- ark:- \
        | ivector-normalize-length ark:- ark:- |" \
      exp/ivectors_$name/plda || exit 1;
  done
fi

# Perform PLDA scoring
if [ $stage -le 5 ]; then
  for name in $test_sets; do
    name=${name}${sad_suffix}
    nf=$(cat data/$name/wav.scp | wc -l)
    diarization/score_plda.sh --cmd "$train_cmd --mem 4G" \
      --nj $(($nf<40?$nf:40)) exp/ivectors_$name \
      exp/ivectors_$name exp/ivectors_$name
  done
fi

# Cluster the PLDA scores using a stopping threshold. (unless we do something better we assume threshold of 0)
if [ $stage -le 6 ]; then
  for name in $test_sets; do
    name=${name}${sad_suffix}
    nf=$(cat data/$name/wav.scp | wc -l)
    diarization/cluster.sh --cmd "$train_cmd --mem 4G" \
      --nj $(($nf<40?$nf:40)) --threshold 0.0 \
      exp/ivectors_$name/plda_scores exp/ivectors_$name/plda_scores

    mkdir -p exp/results/$output_name
    cp exp/ivectors_$name/plda_scores/rttm exp/results/$output_name/${name}.rttm
    if [ -f data/$name/ref.rttm ]; then
      md-eval.pl -r data/$name/ref.rttm -s exp/results/$output_name/${name}.rttm \
        2> exp/results/$output_name/${name}.log \
        > exp/results/$output_name/DER.txt
      der=$(grep -oP 'DIARIZATION\ ERROR\ =\ \K[0-9]+([.][0-9]+)?' \
        exp/results/$output_name/DER.txt)
      echo "Using supervised calibration on $name, DER: $der%"
    fi
  done
fi
