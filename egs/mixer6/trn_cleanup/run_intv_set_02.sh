#!/bin/bash

. cmd.sh
. path.sh
mfccdir=`pwd`/mfcc
vaddir=`pwd`/mfcc
set -e

numjobs=20

if [ 0 == 1 ]; then
## Compute two-channel energy diarization
local/mixer6_ch_data_prep.sh NONE 01 intv raw/intv_set_02/filelist.txt data/intv_set02_CH01_full
local/mixer6_ch_data_prep.sh NONE 02 intv raw/intv_set_02/filelist.txt data/intv_set02_CH02_full

steps/make_mfcc.sh --nj $numjobs --cmd "$train_cmd" --mfcc-config conf/mfcc_hires.conf \
    data/intv_set02_CH01_full exp/make_mfcc/intv_set02_CH01_full $mfccdir || exit 1;
steps/make_mfcc.sh --nj $numjobs --cmd "$train_cmd" --mfcc-config conf/mfcc_hires.conf \
    data/intv_set02_CH02_full exp/make_mfcc/intv_set02_CH02_full $mfccdir || exit 1;

local/compute_energy_diarization.sh --nj $numjobs --cmd "$train_cmd" \
    data/intv_set02_CH02_full data/intv_set02_CH01_full exp/make_vad $vaddir

mkdir -p data/intv_set02_hires_diar
cp data/intv_set02_CH02_full/wav.scp data/intv_set02_hires_diar
rm -f data/intv_set02_hires_diar/segments

copy-vector scp:data/intv_set02_CH02_full/vad.scp ark,t:temp1.txt
for id in $(cat data/intv_set02_CH02_full/wav.scp | awk '{print $1}'); do
  grep -e "$id" temp1.txt | sed -e 's/.*\[ //g' > temp2.txt
  sed -i -e 's/ \]//g' temp2.txt
  sed -i -e 's/ /\n/g' temp2.txt
  local/vad_to_segments.py temp2.txt 0.01 $id >> data/intv_set02_hires_diar/segments
done
rm temp{1,2}.txt

## Setup flat segmentation to decode text
local/mixer6_data_prep.sh /export/speakerphone/data/intv \
    raw/intv_set_02/filelist.txt data/intv_set02_hires_flat

local/create_flat_segmentation.sh data/intv_set02_hires_flat

steps/make_mfcc.sh --nj $numjobs --cmd "$train_cmd" --mfcc-config conf/mfcc_hires.conf \
    data/intv_set02_hires_flat exp/make_mfcc/intv_set02_hires_flat $mfccdir || exit 1;

steps/compute_cmvn_stats.sh data/intv_set02_hires_flat \
    exp/make_mfcc/intv_set02_hires_flat $mfccdir

steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $numjobs \
    data/intv_set02_hires_flat aspire_models/extractor \
    exp/ivectors/ivectors_intv_set02_hires_flat || exit 1;

if [ ! -f aspire_models/tri5a/graph ]; then
  utils/mkgraph.sh data/lang aspire_models/tri5a aspire_models/tri5a/graph
fi

steps/nnet2/decode2.sh --nj $numjobs --cmd "$decode_cmd" --config conf/decode.config \
    --online-ivector-dir exp/ivectors/ivectors_intv_set02_hires_flat \
    aspire_models/tri5a/graph data/intv_set02_hires_flat \
    aspire_models exp/decode_intv_set02_hires_flat || exit 1;

local/get_ctm.sh 10 0 data/lang data/intv_set02_hires_flat \
    aspire_models/final.mdl exp/decode_intv_set02_hires_flat

rm -f exp/decode_intv_set02_hires_flat/score_10/penalty_0/ctm_readable_fullfile_sorted.overlapping
for sess_id in $(cat data/intv_set02_hires_flat/wav.scp | awk '{print $1}'); do
  grep -e "$sess_id" exp/decode_intv_set02_hires_flat/score_10/penalty_0/ctm_readable_fullfile.overlapping |\
      grep -v "\[.*\]" | sort -k3 -n >> \
      exp/decode_intv_set02_hires_flat/score_10/penalty_0/ctm_readable_fullfile_sorted.overlapping
done

## Split diarized segments based on flat segmentation text
local/split_segments_notext.py data/intv_set02_hires_diar \
    exp/decode_intv_set02_hires_flat/score_10/penalty_0/ctm_readable_fullfile_sorted.overlapping \
    10 data/intv_set02_hires_diar_split
cp data/intv_set02_hires_diar/wav.scp data/intv_set02_hires_diar_split
cat data/intv_set02_hires_diar_split/segments | awk '{print $1" "$2}' \
    > data/intv_set02_hires_diar_split/utt2spk
utils/fix_data_dir.sh data/intv_set02_hires_diar_split

steps/make_mfcc.sh --nj $numjobs --cmd "$train_cmd" --mfcc-config conf/mfcc_hires.conf \
    data/intv_set02_hires_diar_split exp/make_mfcc/intv_set02_hires_diar_split $mfccdir || exit 1;

steps/compute_cmvn_stats.sh data/intv_set02_hires_diar_split \
    exp/make_mfcc/intv_set02_hires_diar_split $mfccdir

steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $numjobs \
    data/intv_set02_hires_diar_split aspire_models/extractor \
    exp/ivectors/ivectors_intv_set02_hires_diar_split || exit 1;

## Train interpolated LM based on transcripts
local/train_interpolated_lm.sh raw/intv_set_02/lower data/intv_set02_interp_lm

utils/mkgraph.sh data/intv_set02_interp_lm/lang_interp aspire_models/tri5a \
    data/intv_set02_interp_lm/graph

steps/nnet2/decode2.sh --nj $numjobs --cmd "$decode_cmd" --config conf/decode.config \
    --online-ivector-dir exp/ivectors/ivectors_intv_set02_hires_diar_split \
    data/intv_set02_interp_lm/graph data/intv_set02_hires_diar_split \
    aspire_models exp/decode_intv_set02_hires_diar_split

local/get_ctm.sh 10 0 data/intv_set02_interp_lm/lang_interp data/intv_set02_hires_diar_split \
    aspire_models/final.mdl exp/decode_intv_set02_hires_diar_split

local/decode_to_text.sh data/intv_set02_hires_diar_split data/lang \
    exp/decode_intv_set02_hires_diar_split raw/intv_set_02/lower \
    data/intv_set02_hires_diar_split_text

## Prepare cleanup
mkdir -p data/intv_set02_diar_split_text
cp data/intv_set02_hires_diar_split_text/{segments,spk2utt,text,utt2spk,wav.scp} \
    data/intv_set02_diar_split_text

steps/make_mfcc.sh --nj $numjobs --cmd "$train_cmd" --mfcc-config conf/mfcc.conf \
    data/intv_set02_diar_split_text exp/make_mfcc/intv_set02_diar_split_text $mfccdir || exit 1;

steps/compute_cmvn_stats.sh data/intv_set02_diar_split_text \
    exp/make_mfcc/intv_set02_diar_split_text $mfccdir

steps/cleanup/clean_and_segment_data.sh data/intv_set02_diar_split_text \
    data/lang aspire_models/tri3a exp/tri3a_cleanup_intv_set02_diar_split_text \
    data/intv_set02_diar_split_text_cleaned
fi

grep -e 'csid' exp/tri3a_cleanup_intv_set02_diar_split_text/lattice_oracle/analysis/per_utt_details.txt |\
    awk '{if($3+$4+$6>0){print $1" "($4+$5+$6)/($3+$4+$6)}else{print $1" 0"}}' > scoring/intv_set02_diar_split_text-per_utt_err.txt
cat scoring/intv_set02_diar_split_text-per_utt_err.txt | awk '{print $1}' > temp1.txt
cat data/intv_set02_diar_split_text/segments | awk '{print $1}' > temp2.txt
diff temp2.txt temp1.txt | grep "<" | awk '{print $2" 1"}' >> scoring/intv_set02_diar_split_text-per_utt_err.txt
sort scoring/intv_set02_diar_split_text-per_utt_err.txt -o scoring/intv_set02_diar_split_text-per_utt_err.txt
