#!/bin/bash

. cmd.sh
. path.sh
mfccdir=`pwd`/mfcc
vaddir=`pwd`/mfcc
set -e

if [ 0 == 1 ]; then
## Setup flat segmentation to decode text
local/mixer6_data_prep.sh /export/speakerphone/data/call \
    raw/call_set_01/filelist.txt data/call_set01_hires_flat

local/create_flat_segmentation.sh data/call_set01_hires_flat

steps/make_mfcc.sh --nj 20 --cmd "$train_cmd" --mfcc-config conf/mfcc_hires.conf \
    data/call_set01_hires_flat exp/make_mfcc/call_set01_hires_flat $mfccdir || exit 1;

steps/compute_cmvn_stats.sh data/call_set01_hires_flat \
    exp/make_mfcc/call_set01_hires_flat $mfccdir

steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 20 \
    data/call_set01_hires_flat aspire_models/extractor \
    exp/ivectors/ivectors_call_set01_hires_flat || exit 1;

if [ ! -f aspire_models/tri5a/graph ]; then
  utils/mkgraph.sh data/lang aspire_models/tri5a aspire_models/tri5a/graph
fi

steps/nnet2/decode2.sh --nj 20 --cmd "$decode_cmd" --config conf/decode.config \
    --online-ivector-dir exp/ivectors/ivectors_call_set01_hires_flat \
    aspire_models/tri5a/graph data/call_set01_hires_flat \
    aspire_models exp/decode_call_set01_hires_flat || exit 1;

local/get_ctm.sh 10 0 data/lang data/call_set01_hires_flat \
    aspire_models/final.mdl exp/decode_call_set01_hires_flat

rm -f exp/decode_call_set01_hires_flat/score_10/penalty_0/ctm_readable_fullfile_sorted.overlapping
for sess_id in $(cat data/call_set01_hires_flat/wav.scp | awk '{print $1}'); do
  grep -e "$sess_id" exp/decode_call_set01_hires_flat/score_10/penalty_0/ctm_readable_fullfile.overlapping |\
      grep -v "\[.*\]" | sort -k3 -n >> \
      exp/decode_call_set01_hires_flat/score_10/penalty_0/ctm_readable_fullfile_sorted.overlapping
done

## Prepare one giant segment to split up iteratively
mkdir -p data/call_set01_hires_flat_dummy
rm -f data/call_set01_hires_flat_dummy/segments
for id in $(cat data/call_set01_hires_flat/wav.scp | awk '{print $1}'); do
  grep -e "$id" data/call_set01_hires_flat/segments | head -n 1 | awk '{printf($1" "$2" "$3" ")}' \
      >> data/call_set01_hires_flat_dummy/segments
  grep -e "$id" data/call_set01_hires_flat/segments | tail -n 1 | awk '{printf($4"\n")}' \
      >> data/call_set01_hires_flat_dummy/segments
done

local/split_segments_notext.py data/call_set01_hires_flat_dummy \
    exp/decode_call_set01_hires_flat/score_10/penalty_0/ctm_readable_fullfile_sorted.overlapping \
    5 data/call_set01_hires_split
cp data/call_set01_hires_flat/wav.scp data/call_set01_hires_split
cat data/call_set01_hires_split/segments | awk '{print $1" "$2}' \
    > data/call_set01_hires_split/utt2spk
utils/fix_data_dir.sh data/call_set01_hires_split

steps/make_mfcc.sh --nj 20 --cmd "$train_cmd" --mfcc-config conf/mfcc_hires.conf \
    data/call_set01_hires_split exp/make_mfcc/call_set01_hires_split $mfccdir || exit 1;

steps/compute_cmvn_stats.sh data/call_set01_hires_split \
    exp/make_mfcc/call_set01_hires_split $mfccdir

steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 20 \
    data/call_set01_hires_split aspire_models/extractor \
    exp/ivectors/ivectors_call_set01_hires_split || exit 1;

local/train_interpolated_lm.sh raw/call_set_01/lower data/call_set01_interp_lm

utils/mkgraph.sh data/call_set01_interp_lm/lang_interp aspire_models/tri5a \
    data/call_set01_interp_lm/graph

steps/nnet2/decode2.sh --nj 20 --cmd "$decode_cmd" --config conf/decode.config \
    --online-ivector-dir exp/ivectors/ivectors_call_set01_hires_split \
    data/call_set01_interp_lm/graph data/call_set01_hires_split \
    aspire_models exp/decode_call_set01_hires_split

local/get_ctm.sh 10 0 data/call_set01_interp_lm/lang_interp data/call_set01_hires_split \
    aspire_models/final.mdl exp/decode_call_set01_hires_split
fi

local/decode_to_text.sh data/call_set01_hires_split data/lang \
    exp/decode_call_set01_hires_split raw/call_set_01/lower \
    data/call_set01_hires_split_text

## Prepare cleanup
mkdir -p data/call_set01_split_text
cp data/call_set01_hires_split_text/{segments,spk2utt,text,utt2spk,wav.scp} \
    data/call_set01_split_text

steps/make_mfcc.sh --nj 20 --cmd "$train_cmd" --mfcc-config conf/mfcc.conf \
    data/call_set01_split_text exp/make_mfcc/call_set01_split_text $mfccdir || exit 1;

steps/compute_cmvn_stats.sh data/call_set01_split_text \
    exp/make_mfcc/call_set01_split_text $mfccdir

steps/cleanup/clean_and_segment_data.sh data/call_set01_split_text \
    data/lang aspire_models/tri3a exp/tri3a_cleanup_call_set01_split_text \
    data/call_set01_split_text_cleaned

grep -e 'csid' exp/tri3a_cleanup_call_set01_split_text/lattice_oracle/analysis/per_utt_details.txt \
    | awk '{print $1" "($4+$5+$6)/($3+$4+$6)}' > scoring/call_set01_split_text-per_utt_err.txt
cat scoring/call_set01_split_text-per_utt_err.txt | awk '{print $1}' > temp1.txt
cat data/call_set01_split_text/segments | awk '{print $1}' > temp2.txt
diff temp2.txt temp1.txt | grep "<" | awk '{print $2" 1"}' >> scoring/call_set01_split_text-per_utt_err.txt
sort scoring/call_set01_split_text-per_utt_err.txt -o scoring/call_set01_split_text-per_utt_err.txt
