#!/bin/bash

. ./cmd.sh
. ./path.sh

mic=sdm1
nj=30
ivec_data_prefix=  # prefix for ivec directory
nnet3_affix=_cleaned  # cleanup affix for nnet3 and chain dirs, e.g. _cleaned
tdnn_affix=  #affix for TDNN directory, e.g. "a" or "b", in case we change the configuration.
dir=exp/$mic/chain${nnet3_affix}/tdnn${tdnn_affix}_sp_bi_ihmali
LM=ami_fsh.o3g.kn.pr1-7
graph_dir=$dir/graph_${LM}

. utils/parse_options.sh
set -e -o pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 [options] <data-dir-prefix>"
  echo "e.g.:   run_decode.sh --nj 8 nospk_"
  echo "main options"
  echo "  --ivec_data_prefix <ivec-data-prefix>   # for using pre-existing ivectors"
  echo "  --config <config-file>                  # config containing options"
  echo "  --nj <nj>                               # number of parallel jobs"
  echo "  --cmd <cmd>                             # Command to run in parallel with"
  exit 1;
fi

data_prefix=$1

if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

for decode_set in dev eval; do
  for f in wav.scp glm segments spk2utt utt2spk text stm reco2file_and_channel; do
    if [ ! -f data/${mic}/${data_prefix}${decode_set}_hires/$f ]; then
      echo "$0: malformed data dir"
      echo "    expected $f to exist"
      exit 1
    fi
  done
done

# prepare feats if they do not exist
for decode_set in dev eval; do
  if [ ! -f data/${mic}/${data_prefix}${decode_set}_hires/feats.scp ]; then
    echo "Extracting mfccs"
    steps/make_mfcc.sh --nj $nj --mfcc-config conf/mfcc_hires.conf \
        --cmd "$train_cmd" data/${mic}/${data_prefix}${decode_set}_hires
    utils/fix_data_dir.sh data/${mic}/${data_prefix}${decode_set}_hires
  fi

  if [ ! -f data/${mic}/${data_prefix}${decode_set}_hires/cmvn.scp ]; then
    echo "Computing cmvn"
    steps/compute_cmvn_stats.sh data/${mic}/${data_prefix}${decode_set}_hires
    utils/fix_data_dir.sh data/${mic}/${data_prefix}${decode_set}_hires
  fi

  data=data/${mic}/${data_prefix}${decode_set}_hires
  sdata=$data/split$nj
  [[ -d $sdata && $data/feats.scp -ot $sdata && $data/cmvn.scp -ot $sdata ]] || split_data.sh $data $nj || exit 1;
done

ivec_base_dir=exp/$mic/nnet3${nnet3_affix}

# Check if ivectors exist, if not extract them
for decode_set in dev eval; do
  if [ ! -f $ivec_base_dir/ivectors_${ivec_data_prefix}${decode_set}_hires/ivector_online.scp ]; then
    if [ ! -d data/${mic}/${ivec_data_prefix}${decode_set}_hires ]; then
      echo "$0: attempting to extract ivectors from invalid data dir:"
      echo "    data/${mic}/${ivec_data_prefix}${decode_set}_hires"
      exit 1
    fi
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj "$nj" \
      data/${mic}/${ivec_data_prefix}${decode_set}_hires exp/$mic/nnet3${nnet3_affix}/extractor \
      $ivec_base_dir/ivectors_${ivec_data_prefix}${decode_set}_hires
  fi
done

rm $dir/.error 2>/dev/null || true
for decode_set in dev eval; do
    (
    steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
        --nj $nj --cmd "$decode_cmd" \
        --online-ivector-dir $ivec_base_dir/ivectors_${ivec_data_prefix}${decode_set}_hires \
        --scoring-opts "--min-lmwt 5 " \
       $graph_dir data/$mic/${data_prefix}${decode_set}_hires $dir/decode_${data_prefix}${decode_set} || exit 1;
    ) || touch $dir/.error &
done
wait
if [ -f $dir/.error ]; then
  echo "$0: something went wrong in decoding"
  exit 1
fi

(for d in exp/sdm1/chain_cleaned/tdnn_sp_bi_ihmali/decode_${data_prefix}*; do grep Sum $d/*sc*/*ys | utils/best_wer.sh; done) \
  > RESULTS_${data_prefix}sdm1.txt
