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

# chime5 main directory path
# please change the path accordingly
chime5_corpus=/export/corpora4/CHiME5
json_dir=${chime5_corpus}/transcriptions
audio_dir=${chime5_corpus}/audio

mfccdir=mfcc
xvec_nnet_dir=0007_voxceleb_v2_1a/exp/xvector_nnet_1a

if [ $stage -le 1 ]; then
### Prepare raw data directories
  for sess in S02 S09; do
    local/generate_segments_utt2spk.sh $json_dir/dev/${sess}.json data/sessions/dev/$sess
  done
  utils/combine_data.sh --skip-fix true data/dev_raw data/sessions/dev/{S02,S09}/*/
  sed -i '/redacted/d' data/dev_raw/*

  for sess in S03 S04 S05 S06 S07 S08 S12 S13 S16 S17 S18 S19 S20 S22 S23 S24; do
    local/generate_segments_utt2spk.sh $json_dir/train/${sess}.json data/sessions/train/$sess
  done
  utils/combine_data.sh --skip-fix true data/train_raw data/sessions/train/{S03,S04,S05,S06,S07,S08,S12,S13,S16,S17,S18,S19,S20,S22,S23,S24}/*/
  sed -i '/redacted/d' data/train_raw/*
fi

if [ $stage -le 2 ]; then
### Prepare single-speaker regions by transcript
  mkdir -p tmp_single
  for dset in dev train; do
    # Set up the info of where a speaker is speaking alone
    for sess in $(ls data/sessions/$dset/); do
      for spk in $(ls data/sessions/$dset/$sess/ | grep P); do
        mkdir -p tmp_single/$dset/$sess/$spk
        grep "${spk}_${spk}" data/sessions/$dset/$sess/$spk/segments | cut -d' ' -f3- > tmp_single/$dset/$sess/$spk/trn
      done
      local/trn_to_spk_num.py tmp_single/$dset/$sess/spk_nums tmp_single/$dset/$sess/*/trn
      awk '{if ( $3 == 1 ) {print $0}}' tmp_single/$dset/$sess/spk_nums > tmp_single/$dset/$sess/single_spk
      for spk in $(ls data/sessions/$dset/$sess/ | grep P); do
        local/trn_to_spk_num.py tmp_single/$dset/$sess/$spk/single_spk_segments tmp_single/$dset/$sess/single_spk tmp_single/$dset/$sess/$spk/trn
        sed -i '/ 1$/d' tmp_single/$dset/$sess/$spk/single_spk_segments
      done
    done

    # Prep the data directory for each speaker
    mkdir -p data/${dset}_single_spk
    rm -f data/${dset}_single_spk/{segments,wav.scp,utt2spk}
    for sess in $(ls data/sessions/$dset/); do
      for spk in $(ls data/sessions/$dset/$sess/ | grep P); do
        awk -v sess=$sess -v spk=$spk '{if ($2-$1 >= 1.3) {printf("%s-%s_%s_%07d_%07d %s-%s %0.2f %0.2f\n",sess,spk,spk,$1*100,$2*100,sess,spk,$1,$2)}}' tmp_single/$dset/$sess/$spk/single_spk_segments >> data/${dset}_single_spk/segments
      done
    done
    awk '{print $2}' data/${dset}_single_spk/segments | sort -u | awk -v path="$audio_dir/$dset/" -F'-' '{print $1"-"$2" "path $1"_"$2".wav"}' > data/${dset}_single_spk/wav.scp
    if [ "$dset" == "train" ]; then
      # These particular mics are bad and have been replaced with the next-best mic based on listening tests
      sed -i -e 's/S05_P14/S05_P15/g;s/S23_P54/S23_P56/g' data/${dset}_single_spk/wav.scp
    fi
    awk '{print $1" "$2}' data/${dset}_single_spk/segments > data/${dset}_single_spk/utt2spk
    utils/utt2spk_to_spk2utt.pl data/${dset}_single_spk/utt2spk > data/${dset}_single_spk/spk2utt
    utils/fix_data_dir.sh data/${dset}_single_spk
  done
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

  for dset in dev train; do
    out_data_dir=data/${dset}_sad
    nf=$(cat data/${dset}_single_spk/wav.scp | wc -l)
    steps/segmentation/detect_speech_activity.sh $sad_opts \
      --nj $(($nf<40?$nf:40)) --acwt 0.3 --stage $sad_stage \
      --mfcc-config sad/conf/mfcc_16kHz${sad_mfcc_suffix}.conf \
      --segment-padding 0.05 --transform-probs-opts "--sil-scale=1.0" \
      data/${dset}_single_spk $sad_dir mfcc_hires exp/sad_segmentation${sad_suffix} \
      ${out_data_dir}
  done
fi

if [ $stage -le 4 ]; then
### Merge SAD segmentation with single-speaker regions for all mics
  mkdir -p tmp_single/sad
  for dset in dev train; do
    rm -rf data/${dset}_cleaned
    mkdir -p data/${dset}_cleaned
    # Set up the info of where a speaker is speaking alone
    for sess in $(ls data/sessions/$dset/); do
      for spk in $(ls data/sessions/$dset/$sess/ | grep P); do
        tmp_dir=tmp_single/sad/$dset/$sess/$spk
        mkdir -p $tmp_dir
        grep -e "${sess}-${spk}" data/${dset}_single_spk/segments | cut -d' ' -f3- > $tmp_dir/single_spk.txt
        grep -e "${sess}-${spk}" data/${dset}_sad_seg/segments | cut -d' ' -f3- > $tmp_dir/sad.txt
        local/trn_to_spk_num.py $tmp_dir/sad_single_spk.txt $tmp_dir/sad.txt $tmp_dir/single_spk.txt
        sed -i '/ 1$/d' $tmp_dir/sad_single_spk.txt
      done
      cat tmp_single/sad/$dset/$sess/*/sad_single_spk.txt | sort -n > tmp_single/sad/$dset/$sess/sad_single_spk.txt
      local/time_marks_and_map_to_segments.py tmp_single/sad/$dset/$sess/sad_single_spk.txt \
        data/sessions/$dset/$sess/segment_drift_map.txt tmp_single/sad/$dset/$sess/segments
      for reco in $(ls tmp_single/sad/$dset/$sess/segments); do
        mkdir -p data/${dset}_cleaned/$reco
        cat tmp_single/sad/$dset/$sess/segments/$reco >> data/${dset}_cleaned/$reco/segments
      done
    done

    # Prepare data directories
    for reco in $(ls data/${dset}_cleaned); do
      data_dir=data/${dset}_cleaned/$reco
      sort -o $data_dir/segments $data_dir/segments
      awk -F'[ _]' '{print $1"_"$2"_"$3"_"$4" "$2}' $data_dir/segments > $data_dir/utt2spk
      utils/utt2spk_to_spk2utt.pl $data_dir/utt2spk > $data_dir/spk2utt
      awk '{print $2}' $data_dir/segments | sort -u | \
        awk -v path="$audio_dir/$dset/" -F'-' '{print $1"-"$2" "path $1"_"$2".wav"}' > \
        $data_dir/wav.scp
    done
    mkdir -p data/${dset}_cleaned/close_talking
    for spk in $(ls data/${dset}_cleaned/ | grep P); do
      grep -e "${spk}_${spk}" data/${dset}_cleaned/$spk/segments >> data/${dset}_cleaned/close_talking/segments
    done
    cat data/${dset}_cleaned/P*/wav.scp | sort > data/${dset}_cleaned/close_talking/wav.scp
    if [ "$dset" == "train" ]; then
      # These particular mics are bad and have been replaced with the next-best mic based on listening tests
      sed -i '/^S05-P14/d;/^S23-P54/d' data/${dset}_cleaned/close_talking/segments
      grep -e 'S05-P15_P14' data/${dset}_cleaned/P15/segments | sed -e 's/ S05-P15 / S05-P14 /g' >>\
        data/${dset}_cleaned/close_talking/segments
      grep -e 'S23-P56_P54' data/${dset}_cleaned/P56/segments | sed -e 's/ S23-P56 / S23-P54 /g' >>\
        data/${dset}_cleaned/close_talking/segments
      sort -o data/${dset}_cleaned/close_talking/segments data/${dset}_cleaned/close_talking/segments
      sed -i -e 's/S05_P14/S05_P15/g;s/S23_P54/S23_P56/g' data/${dset}_cleaned/close_talking/wav.scp
    fi
    awk -F'[ _]' '{print $1"_"$2"_"$3"_"$4" "$2}' data/${dset}_cleaned/close_talking/segments > \
      data/${dset}_cleaned/close_talking/utt2spk
    utils/utt2spk_to_spk2utt.pl data/${dset}_cleaned/close_talking/utt2spk > \
      data/${dset}_cleaned/close_talking/spk2utt
    for file in $(ls data/${dset}_cleaned/U*/wav.scp); do
      sed -i -e 's/\(U[0-9][0-9]\)\.wav/\1.CH1.wav/g' $file
    done
  done

  # Channel 2 is (unusably) noisy but present, so we pick that channel for the session directories
  sed -i -e 's/S05-P14 \(.*\)$/S05-P14 sox \1 -t wavpcm - remix 2 |/g' data/train_cleaned/P14/wav.scp
  sed -i -e 's/S23-P54 \(.*\)$/S23-P54 sox \1 -t wavpcm - remix 2 |/g' data/train_cleaned/P54/wav.scp
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
  for dset in dev train; do
    mkdir -p data/${dset}_spk_xvec
    cp data/${dset}_cleaned/close_talking/wav.scp data/${dset}_spk_xvec
    awk '{print $1" "$1}' data/${dset}_spk_xvec/wav.scp | tee data/${dset}_spk_xvec/utt2spk > data/${dset}_spk_xvec/spk2utt
    nf=$(cat data/${dset}_spk_xvec/wav.scp | wc -l)
    steps/make_mfcc.sh --write-utt2num-frames true --mfcc-config 0007_voxceleb_v2_1a/conf/mfcc.conf \
      --nj $(($nf<40?$nf:40)) --cmd "$train_cmd" \
      data/${dset}_spk_xvec exp/make_mfcc $mfccdir
    utils/fix_data_dir.sh data/${dset}_spk_xvec

    local/seg_to_vad.py data/${dset}_cleaned/close_talking/segments data/${dset}_spk_xvec
    mkdir -p $mfccdir/${dset}_spk_xvec_vad
    copy-vector ark,t:data/${dset}_spk_xvec/vad.txt ark,scp:$mfccdir/${dset}_spk_xvec_vad/vad.ark,$mfccdir/${dset}_spk_xvec_vad/vad.scp
    cp $mfccdir/${dset}_spk_xvec_vad/vad.scp data/${dset}_spk_xvec
    rm data/${dset}_spk_xvec/vad.txt
  done
fi

if [ $stage -le 6 ]; then
### Extract speaker-level xvectors
  for dset in dev train; do
    nf=$(cat data/${dset}_spk_xvec/wav.scp | wc -l)
    sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 4G" --nj $(($nf<40?$nf:40)) \
      $xvec_nnet_dir data/${dset}_spk_xvec \
      exp/xvectors_${dset}_spk_xvec
  done
fi

if [ $stage -le 7 ]; then
### Prepare to extract segment-level xvectors
  for dset in dev train; do
    mkdir -p data/${dset}_seg_xvec
    cp data/${dset}_cleaned/close_talking/wav.scp data/${dset}_seg_xvec
    awk -F' ' '{if ($4-$3 >= 1.3) {print $0}}' data/${dset}_cleaned/close_talking/segments > data/${dset}_seg_xvec/segments
    awk '{print $1" "$1}' data/${dset}_seg_xvec/segments | tee data/${dset}_seg_xvec/utt2spk > data/${dset}_seg_xvec/spk2utt
    sed -i -e 's/\([0-9]\) \(\/\)/\1 sox \2/g;s/wav$/wav -t wavpcm - remix 1 |/g' data/${dset}_seg_xvec/wav.scp
    steps/make_mfcc.sh --write-utt2num-frames true --mfcc-config 0007_voxceleb_v2_1a/conf/mfcc.conf \
      --nj 40 --cmd "$train_cmd" \
      data/${dset}_seg_xvec exp/make_mfcc $mfccdir
    utils/fix_data_dir.sh data/${dset}_seg_xvec
    nf=$(cat data/${dset}_spk_xvec/wav.scp | wc -l)
    sid/compute_vad_decision.sh --nj $(($nf<40?$nf:40)) --cmd "$train_cmd" \
      --vad-config 0007_voxceleb_v2_1a/conf/vad.conf \
      data/${dset}_seg_xvec exp/make_vad $mfccdir
    utils/fix_data_dir.sh data/${dset}_seg_xvec
  done
fi

if [ $stage -le 8 ]; then
### Extract segment-level xvectors
  for dset in dev train; do
    sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 4G" --nj 40 \
      $xvec_nnet_dir data/${dset}_seg_xvec \
      exp/xvectors_${dset}_seg_xvec
  done
fi

if [ $stage -le 9 ]; then
### Score segment-level xvectors against speaker-level xvectors
  for dset in dev train; do
    mkdir -p exp/scores_${dset}
    awk -F'[ _]' '{print $1" "$1"_"$2"_"$3"_"$4}' exp/xvectors_${dset}_seg_xvec/xvector.scp > exp/scores_${dset}/trials
    $train_cmd exp/scores_${dset}/log/scoring.log \
      ivector-plda-scoring --normalize-length=true --num-utts=ark:exp/xvectors_${dset}_spk_xvec/num_utts.ark \
      "ivector-copy-plda --smoothing=0.0 $xvec_nnet_dir/xvectors_train/plda - |" \
      "ark:ivector-subtract-global-mean $xvec_nnet_dir/xvectors_train/mean.vec scp:exp/xvectors_${dset}_spk_xvec/xvector.scp ark:- | transform-vec $xvec_nnet_dir/xvectors_train/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
      "ark:ivector-subtract-global-mean $xvec_nnet_dir/xvectors_train/mean.vec scp:exp/xvectors_${dset}_seg_xvec/xvector.scp ark:- | transform-vec $xvec_nnet_dir/xvectors_train/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
      exp/scores_${dset}/trials exp/scores_${dset}/scores.ark || exit 1;
  done
fi

if [ $stage -le 10 ]; then
### Use xvector scores to find "good" segments and create final data directories
  for dset in dev train; do
    mkdir -p data/${dset}_final

    # Create table of utterance equivalences (NOTE: not all of these exist)
    rm -f data/${dset}_final/utt_equivalences.txt
    for sess in $(ls data/sessions/$dset/); do
      for file in tmp_single/sad/$dset/$sess/segments/*; do
        cut -d' ' -f1 $file > ${file}_IDs
      done
      paste -d' ' tmp_single/sad/$dset/$sess/segments/*_IDs >> data/${dset}_final/utt_equivalences.txt
    done

    rm -f data/${dset}_final/key.txt
    while read line; do
      keep=$(grep -e "$line" exp/scores_${dset}/scores.ark | awk '{if($3 > -10) {print "true"}}')
      if [ "$keep" == "true" ]; then
        echo "$line 1" >> data/${dset}_final/key.txt
      else
        echo "$line 0" >> data/${dset}_final/key.txt
      fi
    done < <(cut -d\  -f1 data/${dset}_cleaned/close_talking/segments)

    mkdir -p data/${dset}_final/close_talking
    rm -f data/${dset}_final/close_talking/wav.scp
    paste -d\  data/${dset}_cleaned/close_talking/segments data/${dset}_final/key.txt |\
      awk '{if($6==1){print $1" "$2" "$3" "$4}}' > data/${dset}_final/close_talking/segments
    for reco_id in $(awk '{print $2}' data/${dset}_final/close_talking/segments | sort -u); do
      grep -e "$reco_id" data/${dset}_cleaned/close_talking/wav.scp >> data/${dset}_final/close_talking/wav.scp
    done
    awk -F'[ _]' '{print $1"_"$2"_"$3"_"$4" "$2}' data/${dset}_final/close_talking/segments > data/${dset}_final/close_talking/utt2spk
    utils/utt2spk_to_spk2utt.pl data/${dset}_final/close_talking/utt2spk > data/${dset}_final/close_talking/spk2utt

    for reco in $(ls data/${dset}_cleaned | grep '[PU]'); do
      mkdir -p data/${dset}_final/$reco
      rm -f data/${dset}_final/$reco/wav.scp
      paste -d\  data/${dset}_cleaned/$reco/segments \
        <(for sess in $(cut -d'-' -f1 data/${dset}_cleaned/$reco/wav.scp); do grep "$sess" data/${dset}_final/key.txt; done) |\
        awk '{if(($6 == 1) && ($4-$3 >= 1.295)){print $1" "$2" "$3" "$4}}' > data/${dset}_final/$reco/segments
      for reco_id in $(awk '{print $2}' data/${dset}_final/$reco/segments | sort -u); do
        grep -e "$reco_id" data/${dset}_cleaned/$reco/wav.scp >> data/${dset}_final/$reco/wav.scp
      done
      awk -F'[ _]' '{print $1"_"$2"_"$3"_"$4" "$2}' data/${dset}_final/$reco/segments > data/${dset}_final/$reco/utt2spk
      utils/utt2spk_to_spk2utt.pl data/${dset}_final/$reco/utt2spk > data/${dset}_final/$reco/spk2utt
    done
  done
fi

if [ $stage -le 11 ]; then
### Extract some sample wav files from the close-talking and a farfield mic
  for dset in dev train; do
    for mic in close_talking U01; do
      mkdir -p samples/$mic/$dset/data
      rm -f samples/$mic/$dset/data/{segments,wav.scp}
      for spk in $(ls data/${dset}_final | grep P); do
        grep -e "_${spk}_" data/${dset}_final/$mic/segments | head -n 5 >>\
          samples/$mic/$dset/data/segments
        grep -e "_${spk}_" data/${dset}_final/$mic/segments | tail -n 5 >>\
          samples/$mic/$dset/data/segments
      done
      cp data/${dset}_final/$mic/wav.scp samples/$mic/$dset/data
      local/data_dir_to_wav.sh samples/$mic/$dset/data samples/$mic/$dset/wav
    done
  done
fi
