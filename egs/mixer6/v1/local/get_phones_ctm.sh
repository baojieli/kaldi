# Copyright 2015  Johns Hopkins University (Authors: Vijayaditya Peddinti).  Apache 2.0.

set -e

beam=7
decode_mbr=true
filter_ctm_command=cp
glm=
stm=
window=10
overlap=5
[ -f ./path.sh ] && . ./path.sh
. parse_options.sh || exit 1;

echo $*

if [ $# -ne 6 ]; then
  echo "Usage: $0 [options] <LMWT> <word-ins-penalty> <lang-dir> <data-dir> <model> <decode-dir>"
  echo " e.g.: $0 --decode-mbr true --beam 7 --glm data/dev_aspire/glm \\"
  echo "          --stm data/dev_aspire/stm\\"
  echo "          12 1.5 data/dev_aspire_hires \\"
  echo "          exp/nnet2_multicondition/nnet_ms_a/final.mdl \\"
  echo "          exp/nnet2_multicondition/nnet_ms_a/decode_dev_aspire"
  echo "main options (for others, see top of script file)"
  echo "  --beam <beam>                            # Decoding beam; default 7.0"
  echo "  --decode-mbr <true|false>                # do mbr decoding; default true"
  echo "  --filter_ctm_command <string>            # command for ctm filtering ;default cp"
  echo "  --stm <stm-file>                         # stm file, will score if provided"
  echo "  --glm <glm-file>                         # glm file, needs to be specified along with stm"
  exit 1;
fi

LMWT=$1
wip=$2
lang=$3
data_dir=$4
model=$5
decode_dir=$6

nj=$(cat $decode_dir/num_jobs)
set -o pipefail

mkdir -p $decode_dir/score_$LMWT/penalty_$wip


if [ -f $decode_dir/../frame_shift ]; then
  frame_shift_opt="--frame-shift=$(cat $decode_dir/../frame_shift)"
  echo "$0: $decode_dir/../frame_shift exists, using $frame_shift_opt"
elif [ -f $decode_dir/../frame_subsampling_factor ]; then
  factor=$(cat $decode_dir/../frame_subsampling_factor) || exit 1
  frame_shift_opt="--frame-shift=0.0$factor"
  echo "$0: $decode_dir/../frame_subsampling_factor exists, using $frame_shift_opt"
fi

lat_files=`eval "echo $decode_dir/lat.{1..$nj}.gz"`

#lattice-scale --inv-acoustic-scale=$LMWT "ark:gunzip -c $lat_files|" ark:- | \
#lattice-add-penalty --word-ins-penalty=$wip ark:- ark:- | \
#lattice-prune --beam=$beam ark:- ark:- | \
lattice-1best --lm-scale=$LMWT "ark:gunzip -c $lat_files|" ark:- |\
lattice-to-ctm-conf $frame_shift_opt --decode-mbr=$decode_mbr ark:- $decode_dir/score_$LMWT/penalty_$wip/ctm.overlapping || exit 1;
utils/int2sym.pl -f 5 $lang/words.txt < $decode_dir/score_$LMWT/penalty_$wip/ctm.overlapping > $decode_dir/score_$LMWT/penalty_$wip/ctm_readable.overlapping
cat $data_dir/utt2spk | awk '{print $2" "$2" 1"}' > $data_dir/reco2file_and_channel
utils/convert_ctm.pl $data_dir/segments $data_dir/reco2file_and_channel $decode_dir/score_$LMWT/penalty_$wip/ctm_readable.overlapping > $decode_dir/score_$LMWT/penalty_$wip/ctm_readable_fullfile.overlapping

