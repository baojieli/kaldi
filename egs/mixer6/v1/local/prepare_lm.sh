#!/bin/bash
# Copyright 2015-2016  Sarah Flora Juan
# Copyright 2016  Johns Hopkins University (Author: Yenda Trmal)
# Apache 2.0

set -e -o pipefail

# To create G.fst from ARPA language model
. ./path.sh || die "path.sh expected";

if [ 0 == 1 ]; then
local/train_lms_srilm.sh --train-text aspire_models/text data/ data/aspirelm
local/train_lms_srilm.sh --train-text data/local/text_all_books data/ data/bookslm

# let's do ngram interpolation of the previous two LMs
# the lm.gz is always symlink to the model with the best perplexity, so we use that
fi

mkdir -p data/lm_interp
for w in 0.05 0.02 0.01; do
    ngram -lm data/bookslm/lm.gz  -mix-lm data/aspirelm/lm.gz \
          -lambda $w -write-lm data/lm_interp/lm.${w}.gz
    echo -n "data/lm_interp/lm.${w}.gz "
    ngram -lm data/lm_interp/lm.${w}.gz -ppl data/bookslm/dev.txt | paste -s
done | sort  -k15,15g  > data/lm_interp/perplexities.txt

lm=data/lm_interp/lm.0.01.gz

gunzip -c "$lm" | \
   grep -v '<s> <s>' | \
   grep -v '</s> <s>' | \
   grep -v '</s> </s>' | \
   arpa2fst - | fstprint | \
   utils/remove_oovs.pl /dev/null | \
   utils/eps2disambig.pl | utils/s2eps.pl | fstcompile --isymbols=data/lang/words.txt \
     --osymbols=data/lang/words.txt  --keep_isymbols=false --keep_osymbols=false | \
    fstrmepsilon | fstarcsort --sort_type=ilabel > data/lang_interp/G.fst

exit

# for basic decoding, let's use only a trigram LM
[ -d data/lang_test/ ] && rm -rf data/lang_test
cp -R data/lang data/lang_test
lm=$(cat data/srilm/perplexities.txt | grep 3gram | head -n1 | awk '{print $1}')
local/arpa2G.sh $lm data/lang_test data/lang_test

# for decoding using bigger LM let's find which interpolated gave the most improvement
[ -d data/lang_big ] && rm -rf data/lang_big
cp -R data/lang data/lang_big
lm=$(cat data/srilm_interp/perplexities.txt | head -n1 | awk '{print $1}')
local/arpa2G.sh $lm data/lang_big data/lang_big

# for really big lm, we should only decode using small LM
# and resocre using the big lm
utils/build_const_arpa_lm.sh $lm data/lang_big data/lang_big
exit 0;
