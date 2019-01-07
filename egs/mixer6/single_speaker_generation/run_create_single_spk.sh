#!/bin/bash
#
# Copyright  2017  Johns Hopkins University
# Apache 2.0
#

# Begin configuration section.
stage=1
save_stats=true
# End configuration section
. ./utils/parse_options.sh

. ./cmd.sh
. ./path.sh


set -e # exit on error

mfccdir=mfcc
vaddir=mfcc

corpus_dir=/export/corpora5/LDC/LDC2013S03
xvec_nnet_dir=0007_voxceleb_v2_1a/exp/xvector_nnet_1a

if [ $stage -le 1 ]; then
### Prepare data
  for ch in 01 02; do
    local/mixer6_ch_data_prep.sh $corpus_dir $ch intv data/intv_CH$ch
    sed -i -e 's/|/gain 15 |/g' data/intv_CH$ch/wav.scp

    steps/make_mfcc.sh --nj 20 --cmd "$train_cmd" --mfcc-config conf/mfcc.conf --write-utt2num-frames true \
      data/intv_CH$ch exp/make_mfcc $mfccdir
    utils/fix_data_dir.sh data/intv_CH$ch
  done
fi

if [ $stage -le 2 ]; then
### Segment based on energy ratio of interviewee and interviewer mics
  local/compute_energy_diarization.sh --nj 20 --cmd "$train_cmd" \
    data/intv_CH02 data/intv_CH01 exp/make_vad $vaddir
  utils/fix_data_dir.sh data/intv_CH02

  echo "0.01" > data/intv_CH02/frame_shift
  diarization/vad_to_segments.sh data/intv_CH02 data/intv_CH02_vad_seg

  mv data/intv_CH02_vad_seg/segments data/intv_CH02_vad_seg/old_segments
  local/merge_segments.py data/intv_CH02_vad_seg/old_segments data/intv_CH02_vad_seg/segments

  if [ "$save_stats" = true ]; then
    rm -f vad_percentage_stats.txt
    for reco in $(cut -d' ' -f1 data/intv_CH02_vad_seg/wav.scp); do
      dur=$(grep -e "$reco" data/intv_CH02_vad_seg/wav.scp | awk -F'[ =]' '{print $14-$12}')
      percentage=$(grep -e "$reco" data/intv_CH02_vad_seg/segments | awk -v dur=$dur 'BEGIN {sum = 0} {sum += $4-$3} END {print sum/dur}')
      echo "$reco $percentage" >> vad_percentage_stats.txt
    done
    sort -k2 vad_percentage_stats.txt -o vad_percentage_stats.txt
  fi
fi

############
#
# This is the part where we run a speech activity detector. I used a SAD system
#  taken from Vimal from the following location on the CLSP servers:
#
# /export/a16/vmanoha1/workspace_dihard/egs/librispeech/s5/exp/segmentation_1a/tdnn_stats_asr_sad_1a
#
# The 'sad' directory contains the following:
#
# sad/
#   conf/
#     mfcc_16kHz_hires.conf
#     mfcc_8kHz_hires_bp.conf
#     mfcc_8kHz_ivector.conf
#     mfcc_8kHz_xvector.conf
#     vad.conf
#   tdnn_stats_asr_sad_1a/
#     cmvn_opts
#     final.raw
#     frame_subsampling_factor
#     lda.mat
#     lda_stats
#     post_output.vec
#
if [ $stage -le 3 ]; then
### Run segmentation
  sad_opts="--extra-left-context 79 --extra-right-context 21 --frames-per-chunk 150 --extra-left-context-initial 0 --extra-right-context-final 0 --acwt 0.3"
  sad_stage=0
  sad_mfcc_suffix="_hires"
  sad_dir=sad/tdnn_stats_asr_sad_1a
  sad_suffix=_1a

  out_data_dir=data/intv_CH02_sad
  steps/segmentation/detect_speech_activity.sh $sad_opts \
    --nj 40 --acwt 0.3 --stage $sad_stage \
    --mfcc-config sad/conf/mfcc_16kHz${sad_mfcc_suffix}.conf \
    --segment-padding 0.05 --transform-probs-opts "--sil-scale=1.0" \
    data/intv_CH02 $sad_dir mfcc_hires exp/sad_segmentation${sad_suffix} \
    ${out_data_dir}

  mv data/intv_CH02_sad_seg/segments data/intv_CH02_sad_seg/old_segments
  local/merge_segments.py data/intv_CH02_sad_seg/old_segments data/intv_CH02_sad_seg/segments

  if [ "$save_stats" = true ]; then
    rm -f sad_percentage_stats.txt
    for reco in $(cut -d' ' -f1 data/intv_CH02_sad_seg/wav.scp); do
      dur=$(grep -e "$reco" data/intv_CH02_sad_seg/wav.scp | awk -F'[ =]' '{print $14-$12}')
      percentage=$(grep -e "$reco" data/intv_CH02_sad_seg/segments | awk -v dur=$dur 'BEGIN {sum = 0} {sum += $4-$3} END {print sum/dur}')
      echo "$reco $percentage" >> sad_percentage_stats.txt
    done
    sort -k2 sad_percentage_stats.txt -o sad_percentage_stats.txt
  fi
fi

if [ $stage -le 4 ]; then
### Compute overlap of VAD and SAD for final segmentation
  tmpdir=tmp_single/sad
  mkdir -p $tmpdir
  rm -rf data/intv_CH02_cleaned
  mkdir -p data/intv_CH02_cleaned

  for reco in $(cut -d' ' -f1 data/intv_CH02/wav.scp); do
    grep -e "$reco" data/intv_CH02_vad_seg/segments | cut -d' ' -f3- > $tmpdir/vad_trn.txt
    grep -e "$reco" data/intv_CH02_sad_seg/segments | cut -d' ' -f3- > $tmpdir/sad_trn.txt
    local/trn_to_spk_num.py $tmpdir/merged_trn.txt $tmpdir/vad_trn.txt $tmpdir/sad_trn.txt
    sed -i '/ 1$/d' $tmpdir/merged_trn.txt
    awk -v reco=$reco '{if ($2-$1 >= 1.3) {printf("%s_%06d_%06d %s %0.2f %0.2f\n",reco,$1*100,$2*100,reco,$1,$2)}}' $tmpdir/merged_trn.txt \
      >> data/intv_CH02_cleaned/segments
  done
  cp data/intv_CH02/wav.scp data/intv_CH02_cleaned

  if [ "$save_stats" = true ]; then
    rm -f cleaned_percentage_stats.txt
    for reco in $(cut -d' ' -f1 data/intv_CH02_cleaned/wav.scp); do
      dur=$(grep -e "$reco" data/intv_CH02_cleaned/wav.scp | awk -F'[ =]' '{print $14-$12}')
      percentage=$(grep -e "$reco" data/intv_CH02_cleaned/segments | awk -v dur=$dur 'BEGIN {sum = 0} {sum += $4-$3} END {print sum/dur}')
      echo "$reco $percentage" >> cleaned_percentage_stats.txt
    done
    sort -k2 cleaned_percentage_stats.txt -o cleaned_percentage_stats.txt
  fi
fi

############
#
# This is where we start using xvectors for segment verification. The model
#  used can be downloaded at:
#
# http://kaldi-asr.org/models/m7
#
# The file should be 0007_voxceleb_v2_1a.tar.gz and should be extracted into
#  the base recipe directory
#
# At time of writing, the 0007_voxceleb_v2_1a/conf subdirectory was missing
#  from the archive and can be copied from the voxceleb recipe:
#
# egs/voxceleb/v2/conf
#
if [ $stage -le 5 ]; then
### Prepare for speaker xvector extraction for segment verification
  mkdir -p data/intv_CH10_spk_xvec
  sed -e 's/CH02/CH10/g' data/intv_CH02_cleaned/wav.scp > data/intv_CH10_spk_xvec/wav.scp
  awk '{print $1" "$1}' data/intv_CH10_spk_xvec/wav.scp \
    | tee data/intv_CH10_spk_xvec/utt2spk > data/intv_CH10_spk_xvec/spk2utt
  steps/make_mfcc.sh --write-utt2num-frames true --mfcc-config 0007_voxceleb_v2_1a/conf/mfcc.conf \
    --nj 40 --cmd "$train_cmd" \
    data/intv_CH10_spk_xvec exp/make_mfcc $mfccdir
  utils/fix_data_dir.sh data/intv_CH10_spk_xvec

  local/seg_to_vad.py data/intv_CH02_cleaned/segments data/intv_CH10_spk_xvec
  mkdir -p $mfccdir/intv_CH10_spk_xvec_vad
  copy-vector ark,t:data/intv_CH10_spk_xvec/vad.txt ark,scp:$mfccdir/intv_CH10_spk_xvec_vad/vad.ark,$mfccdir/intv_CH10_spk_xvec_vad/vad.scp
  cp $mfccdir/intv_CH10_spk_xvec_vad/vad.scp data/intv_CH10_spk_xvec
  rm data/intv_CH10_spk_xvec/vad.txt
fi

if [ $stage -le 6 ]; then
### Extract speaker-level xvectors
  sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 4G" --nj 40 \
    $xvec_nnet_dir data/intv_CH10_spk_xvec \
    exp/xvectors_intv_CH10_spk_xvec
fi

if [ $stage -le 7 ]; then
### Prepare to extract segment-level xvectors
  mkdir -p data/intv_CH10_seg_xvec
  cp data/intv_CH02_cleaned/segments data/intv_CH10_seg_xvec
  cp data/intv_CH10_spk_xvec/wav.scp data/intv_CH10_seg_xvec
  awk '{print $1" "$1}' data/intv_CH10_seg_xvec/segments \
    | tee data/intv_CH10_seg_xvec/utt2spk > data/intv_CH10_seg_xvec/spk2utt
  steps/make_mfcc.sh --write-utt2num-frames true --mfcc-config 0007_voxceleb_v2_1a/conf/mfcc.conf \
    --nj 40 --cmd "$train_cmd" \
    data/intv_CH10_seg_xvec exp/make_mfcc $mfccdir
  utils/fix_data_dir.sh data/intv_CH10_seg_xvec
  sid/compute_vad_decision.sh --nj 40 --cmd "$train_cmd" \
    --vad-config 0007_voxceleb_v2_1a/conf/vad.conf \
    data/intv_CH10_seg_xvec exp/make_vad $mfccdir
  utils/fix_data_dir.sh data/intv_CH10_seg_xvec
fi

if [ $stage -le 8 ]; then
### Extract segment-level xvectors
  sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 4G" --nj 40 \
    $xvec_nnet_dir data/intv_CH10_seg_xvec \
    exp/xvectors_intv_CH10_seg_xvec
fi

if [ $stage -le 9 ]; then
### Score segment-level xvectors against speaker-level xvectors
  mkdir -p exp/scores_intv_CH10
  awk -F'[ _]' '{print $1"_"$2"_"$3"_"$4" "$1"_"$2"_"$3"_"$4"_"$5"_"$6}' exp/xvectors_intv_CH10_seg_xvec/xvector.scp \
    > exp/scores_intv_CH10/trials
  $train_cmd exp/scores_intv_CH10/log/scoring.log \
    ivector-plda-scoring --normalize-length=true --num-utts=ark:exp/xvectors_intv_CH10_spk_xvec/num_utts.ark \
    "ivector-copy-plda --smoothing=0.0 $xvec_nnet_dir/xvectors_train/plda - |" \
    "ark:ivector-subtract-global-mean $xvec_nnet_dir/xvectors_train/mean.vec scp:exp/xvectors_intv_CH10_spk_xvec/xvector.scp ark:- | transform-vec $xvec_nnet_dir/xvectors_train/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "ark:ivector-subtract-global-mean $xvec_nnet_dir/xvectors_train/mean.vec scp:exp/xvectors_intv_CH10_seg_xvec/xvector.scp ark:- | transform-vec $xvec_nnet_dir/xvectors_train/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    exp/scores_intv_CH10/trials exp/scores_intv_CH10/scores.ark || exit 1;
fi

if [ $stage -le 10 ]; then
### Use xvector scores to find "good" segments and create final data directories
  mkdir -p data/intv_final
  rm -f data/intv_final/key.txt
  while read line; do
    keep=$(grep -e "$line" exp/scores_intv_CH10/scores.ark | awk '{if($3 > 4) {print "true"}}')
    if [ "$keep" == "true" ]; then
      echo "$line 1" >> data/intv_final/key.txt
    else
      echo "$line 0" >> data/intv_final/key.txt
    fi
  done < <(cut -d\  -f1 data/intv_CH02_cleaned/segments)

  paste -d\  data/intv_CH02_cleaned/segments data/intv_final/key.txt |\
    awk '{if($6==1){print $1" "$2" "$3" "$4}}' > data/intv_final/segments
  awk -F'[ _]' '{print $1"_"$2"_"$3"_"$4"_"$5"_"$6" "$4}' data/intv_final/segments > data/intv_final/utt2spk
  utils/utt2spk_to_spk2utt.pl data/intv_final/utt2spk > data/intv_final/spk2utt
fi

if [ $stage -le 11 ]; then
### Extract some sample wav files from the
  for ch in 02 09 13; do
    local/mixer6_ch_single_speaker_data_prep.sh $corpus_dir $ch intv data/intv_CH${ch}_final
    if [ "$ch" == "13" ]; then
      sed -i -e 's/|/gain 9 |/g' data/intv_CH${ch}_final/wav.scp
    else
      sed -i -e 's/|/gain 15 |/g' data/intv_CH${ch}_final/wav.scp
    fi

    mkdir -p samples/intv_CH$ch/data
    rm -f samples/intv_CH$ch/data/{segments,wav.scp}
    for spk in $(cut -d' ' -f1 data/intv_CH${ch}_final/spk2utt); do
      grep -e "[CM]_$spk " data/intv_CH${ch}_final/segments | head -n 1 >>\
        samples/intv_CH${ch}/data/segments
      grep -e "[CM]_$spk " data/intv_CH${ch}_final/segments | tail -n 1 >>\
        samples/intv_CH${ch}/data/segments
      grep -e "[CM]_$spk " data/intv_CH${ch}_final/wav.scp | head -n 1 >>\
        samples/intv_CH${ch}/data/wav.scp
      grep -e "[CM]_$spk " data/intv_CH${ch}_final/wav.scp | tail -n 1 >>\
        samples/intv_CH${ch}/data/wav.scp
    done
    sed -e 's/ \([0-9]*\)_.*$/ \1/g' samples/intv_CH${ch}/data/segments > samples/intv_CH${ch}/data/utt2spk
    utils/fix_data_dir.sh samples/intv_CH${ch}/data
    local/data_dir_to_wav.sh samples/intv_CH${ch}/data samples/intv_CH${ch}/wav
  done
fi
