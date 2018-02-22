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

# Location of https://github.com/nryant/dscore
dscore_path=$KALDI_ROOT/../dscore

# If both an ivector and xvector extractor are supplied, PLDA scores for both are fused
sad_dir=models/sad/stock
ivector_dir=
xvector_dir=
output_name=default

train_sets="train"
test_sets="test"

sad_mfcc_suffix="_hires_bp"
ivector_mfcc_suffix="_ivector"
xvector_mfcc_suffix="_xvector"

. parse_options.sh || exit 1;

if [ ! -z "$sad_dir" ]; then sad_suffix="_sad"; fi
if [ ! -z "$ivector_dir" ]; then conf_suffix="$conf_suffix $ivector_mfcc_suffix"; fi
if [ ! -z "$xvector_dir" ]; then conf_suffix="$conf_suffix $xvector_mfcc_suffix"; fi
if [ -z "$conf_suffix" ]; then
  echo "ERROR: You appear to be using neither an ivector or xvector extractor"
  exit 0
fi

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
      --mfcc-config conf/mfcc_8kHz${sad_mfcc_suffix}.conf --feat-affix bp \
      data/$name $sad_dir mfcc_hires_bp exp/sad_segmentation_$name \
      data/${name}${sad_suffix}
  done
fi

if [ ! -z "$sad_dir" ]; then sad_suffix=${sad_suffix}_seg; fi

# Prepare features
if [ $stage -le 2 ]; then
  for suffix in $conf_suffix; do
    for name in $train_sets; do
      cp -r data/$name data/${name}${suffix}
      steps/make_mfcc.sh --mfcc-config conf/mfcc_8kHz${suffix}.conf --nj 40 \
        --cmd "$train_cmd" --write-utt2num-frames true \
      data/${name}${suffix} exp/make_mfcc $mfccdir
      utils/fix_data_dir.sh data/${name}${suffix}

      nf=$(cat data/$name/wav.scp | wc -l)
      sid/compute_vad_decision.sh --nj $(($nf<40?$nf:40)) --cmd "$train_cmd" \
        data/${name}${suffix} exp/make_vad $vaddir
      utils/fix_data_dir.sh data/${name}${suffix}
    done

    for name in $test_sets; do
      name=${name}${sad_suffix}
      cp -r data/$name data/${name}${suffix}
      steps/make_mfcc.sh --mfcc-config conf/mfcc_8kHz${suffix}.conf --nj 40 \
        --cmd "$train_cmd" --write-utt2num-frames true \
        data/${name}${suffix} exp/make_mfcc $mfccdir
      utils/fix_data_dir.sh data/${name}${suffix}

      nf=$(cat data/$name/wav.scp | wc -l)
      sid/compute_vad_decision.sh --nj $(($nf<40?$nf:40)) --cmd "$train_cmd" \
        data/${name}${suffix} exp/make_vad $vaddir
      utils/fix_data_dir.sh data/${name}${suffix}
    done
  done

  # Write CMN features to disk for xvector
  if [ ! -z "$xvector_dir" ]; then
    for name in $train_sets; do
      local/nnet3/xvector/prepare_feats.sh --nj 40 --cmd "$train_cmd" \
        data/${name}${xvector_mfcc_suffix} \
        data/${name}${xvector_mfcc_suffix}_cmn exp/${name}${xvector_mfcc_suffix}_cmn
      utils/fix_data_dir.sh data/${name}${xvector_mfcc_suffix}_cmn
    done

    for name in $test_sets; do
      name=${name}${sad_suffix}
      local/nnet3/xvector/prepare_feats.sh --nj 40 --cmd "$train_cmd" \
        data/${name}${xvector_mfcc_suffix} \
        data/${name}${xvector_mfcc_suffix}_cmn exp/${name}${xvector_mfcc_suffix}_cmn
      utils/fix_data_dir.sh data/${name}${xvector_mfcc_suffix}_cmn
    done
  fi

#  For PLDA training data that does not have segmentation, segmentation needs
#    to be created. This uses the simple energy VAD but we maybe should use
#    a better SAD since our training data may not be as clean.
#
#  # Create segments for ivector extraction for PLDA training data.
#  echo "0.01" > data/sre/frame_shift
#  diarization/vad_to_segments.sh --nj 40 --cmd "$train_cmd" \
#    data/sre data/sre_segmented
fi

# Extract spk representation
if [ $stage -le 3 ]; then
  if [ ! -z "$ivector_dir" ]; then  # Extract ivectors
    for name in $train_sets; do
      name=${name}${ivector_mfcc_suffix}
      nf=$(cat data/$name/wav.scp | wc -l)
      diarization/extract_ivectors.sh --cmd "$train_cmd --mem 25G" \
        --nj $(($nf<40?$nf:40)) --window 3.0 --period 10.0 --min-segment 1.5 \
        --apply-cmn false --hard-min true $ivector_dir data/$name \
        exp/ivectors_$name
    done

    for name in $test_sets; do
      name=${name}${sad_suffix}${ivector_mfcc_suffix}
      nf=$(cat data/$name/wav.scp | wc -l)
      diarization/extract_ivectors.sh --cmd "$train_cmd --mem 20G" \
        --nj $(($nf<40?$nf:40)) --window 1.5 --period 0.75 --apply-cmn false \
        --min-segment 0.5 $ivector_dir data/$name exp/ivectors_$name
    done
  fi

  if [ ! -z "$xvector_dir" ]; then  # Extract xvectors
    for name in $train_sets; do
      name=${name}${xvector_mfcc_suffix}_cmn
      diarization/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 10G" \
        --nj 40 --window 3.0 --period 10.0 --min-segment 1.5 --apply-cmn false \
        --hard-min true $xvector_dir data/$name exp/xvectors_$name
    done

    for name in $test_sets; do
      name=${name}${sad_suffix}${xvector_mfcc_suffix}_cmn
      diarization/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 10G" \
        --nj 40 --window 1.5 --period 0.75 --apply-cmn false \
        --min-segment 0.5 $xvector_dir data/$name exp/xvectors_$name
    done
  fi
fi

# Train PLDA models  ##### note: this is whitening using the test data
if [ $stage -le 4 ]; then
  if [ ! -z "$ivector_dir" ]; then
    for name in $test_sets; do
      name=${name}${sad_suffix}${ivector_mfcc_suffix}

      # Prepare PLDA training data
      mkdir -p exp/ivectors_$name/log
      for file in ivector.scp spk2utt; do
        rm -f exp/ivectors_$name/log/$file
        for train_name in $train_sets; do
          train_name=${train_name}${ivector_mfcc_suffix}
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

  if [ ! -z "$xvector_dir" ]; then
    for name in $test_sets; do
      name=${name}${sad_suffix}${xvector_mfcc_suffix}_cmn

      # Prepare PLDA training data
      mkdir -p exp/xvectors_$name/log
      for file in xvector.scp spk2utt; do
        rm -f exp/xvectors_$name/log/$file
        for train_name in $train_sets; do
          train_name=${train_name}${xvector_mfcc_suffix}_cmn
          cat exp/xvectors_$train_name/$file >> exp/xvectors_$name/log/$file
        done
        sort exp/xvectors_$name/log/$file -o exp/xvectors_$name/log/$file
      done

      # Train PLDA
      "$train_cmd" exp/xvectors_$name/log/plda.log \
        ivector-compute-plda ark:exp/xvectors_$name/log/spk2utt \
          "ark:ivector-subtract-global-mean \
          scp:exp/xvectors_$name/log/xvector.scp ark:- \
          | transform-vec exp/xvectors_$name/transform.mat ark:- ark:- \
          | ivector-normalize-length ark:- ark:- |" \
        exp/xvectors_$name/plda || exit 1;
    done
  fi
fi

# Perform PLDA scoring
if [ $stage -le 5 ]; then
  if [ ! -z "$ivector_dir" ]; then
    for name in $test_sets; do
      name=${name}${sad_suffix}${ivector_mfcc_suffix}
      nf=$(cat data/$name/wav.scp | wc -l)
      diarization/score_plda.sh --cmd "$train_cmd --mem 4G" \
        --nj $(($nf<40?$nf:40)) exp/ivectors_$name \
        exp/ivectors_$name exp/ivectors_$name/plda_scores
    done
  fi

  if [ ! -z "$xvector_dir" ]; then
    for name in $test_sets; do
      name=${name}${sad_suffix}${xvector_mfcc_suffix}_cmn
      nf=$(cat data/$name/wav.scp | wc -l)
      diarization/score_plda.sh --cmd "$train_cmd --mem 4G" \
        --nj $(($nf<40?$nf:40)) --xvector true exp/xvectors_$name \
        exp/xvectors_$name exp/xvectors_$name/plda_scores
    done
  fi
fi

# Sum PLDA score matrices
if [ $stage -le 6 ]; then
  for name in $test_sets; do
    mkdir -p exp/${output_name}_plda_scores/$name
    score_mats=""
    if [ ! -z "$ivector_dir" ]; then
      ivecname=${name}${sad_suffix}${ivector_mfcc_suffix}
      score_mats="$score_mats scp:exp/ivectors_$ivecname/plda_scores/scores.scp"
      cp exp/ivectors_$ivecname/plda_scores/{utt2spk,spk2utt,segments} \
        exp/${output_name}_plda_scores/$name
    fi

    if [ ! -z "xvector_dir" ]; then
      xvecname=${name}${sad_suffix}${xvector_mfcc_suffix}_cmn
      score_mats="$score_mats scp:exp/xvectors_$xvecname/plda_scores/scores.scp"
      cp exp/xvectors_$xvecname/plda_scores/{utt2spk,spk2utt,segments} \
        exp/${output_name}_plda_scores/$name
    fi

    # Should probably make a script that does this using the queue
    "$train_cmd" exp/${output_name}_plda_scores/$name/log/matrix_sum.log \
      matrix-sum $score_mats \
      ark,scp:exp/${output_name}_plda_scores/$name/scores.ark,exp/${output_name}_plda_scores/$name/scores.scp
  done
fi

# Cluster the PLDA scores using a stopping threshold. (unless we do something better we assume threshold of 0)
if [ $stage -le 7 ]; then
  for name in $test_sets; do
#    name=${name}${sad_suffix}
#    nf=$(cat data/$name/wav.scp | wc -l)
#    diarization/cluster.sh --cmd "$train_cmd --mem 4G" \
#      --nj $(($nf<40?$nf:40)) --threshold 0.0 \
#      exp/ivectors_$name/plda_scores exp/ivectors_$name/plda_scores
    nf=$(cat data/$name/wav.scp | wc -l)
    diarization/cluster.sh --cmd "$train_cmd --mem 4G" \
      --nj $(($nf<40?$nf:40)) --threshold 0.0 \
      exp/${output_name}_plda_scores/$name \
      exp/${output_name}_plda_scores/$name

    mkdir -p exp/results/$output_name
    cp exp/${output_name}_plda_scores/$name/rttm exp/results/$output_name/${name}.rttm
  done
fi

# Compute DER%
if [ $stage -le 8 ]; then
  for name in $test_sets; do
    if [ -f data/$name/ref.rttm ]; then
      md-eval.pl -r data/$name/ref.rttm -s exp/results/$output_name/${name}.rttm \
        2> exp/results/$output_name/${name}.log \
        > exp/results/$output_name/DER_${name}.txt
      der=$(grep -oP 'DIARIZATION\ ERROR\ =\ \K[0-9]+([.][0-9]+)?' \
        exp/results/$output_name/DER_${name}.txt)
      echo "Using supervised calibration on $name, DER: $der%"
    fi

    if [ ! -z "$dscore_path" ]; then
      export PATH=$dscore_path:$PATH

      # dscore complains about segments of length 0
      awk '{if ($5 > 0) {print $0}}' data/$name/ref.rttm \
        > exp/results/$output_name/ref_${name}.rttm

      # we are scoring everything so we can generate our own uem file
      if [ ! -f data/$name/ref.uem ]; then
        "$train_cmd" data/$name/log/wav_to_duration_for_uem.log \
          wav-to-duration scp:data/$name/wav.scp ark,t:- \
          \| sed -e 's/ $//g;s/ / 1 0.0 /g' \> data/$name/ref.uem
      fi

      if [ -f data/$name/ref.uem ]; then
        score.py -u data/$name/ref.uem -r exp/results/$output_name/ref_${name}.rttm \
          -s exp/results/$output_name/${name}.rttm \
          2> exp/results/$output_name/${name}_dscore.log \
          > exp/results/$output_name/dscore_${name}.txt
      else
        score.py -r exp/results/$output_name/ref_${name}.rttm \
          -s exp/results/$output_name/${name}.rttm \
          2> exp/results/$output_name/${name}_dscore.log \
          > exp/results/$output_name/dscore_${name}.txt
      fi
      echo "Output of dscore:"
      head -n 1 exp/results/$output_name/dscore_${name}.txt
      tail -n 1 exp/results/$output_name/dscore_${name}.txt
    fi
  done
fi
