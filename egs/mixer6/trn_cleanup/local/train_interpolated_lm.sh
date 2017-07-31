#!/bin/bash

set -e -o pipefail

. ./path.sh

trndir=$1
outdir=$2

rm -f all_text.tmp
rm -f all_train_text.tmp
for file in $trndir/*.txt; do
  cat $file | awk '{print "<text> "$0}' >> all_train_text.tmp
  cat $file >> all_text.tmp
done
mkdir -p $outdir

## train independent LMs
local/train_lms_srilm_2g.sh --train-text aspire_models/text data/ data/aspire_lm
local/train_lms_srilm_5g.sh --train-text all_train_text.tmp \
    --dev-text all_train_text.tmp data/ $outdir/trn_lm

## interpolate LMs
# note: lms were selected manually
for w in 0.75 0.8 0.85 0.9 0.95; do
    ngram -lm $outdir/trn_lm/lm.gz  -mix-lm data/aspire_lm/lm.gz \
          -lambda $w -write-lm $outdir/lm.${w}.gz
    echo -n "$outdir/lm.${w}.gz "
    ngram -lm $outdir/lm.${w}.gz -ppl all_text.tmp | paste -s
done | sort  -k15,15g  > $outdir/perplexities.txt

# manually picked through iterative runs on LM weights
lm=$(head -n 1 $outdir/perplexities.txt | awk '{print $1}')

mkdir -p $outdir/lang_interp
cp -r data/lang/{L.fst,L_disambig.fst,phones,phones.txt,words.txt} $outdir/lang_interp

gunzip -c "$lm" | \
   grep -v '<s> <s>' | \
   grep -v '</s> <s>' | \
   grep -v '</s> </s>' | \
   arpa2fst - | fstprint | \
   utils/remove_oovs.pl /dev/null | \
   utils/eps2disambig.pl | utils/s2eps.pl | fstcompile --isymbols=data/lang/words.txt \
     --osymbols=data/lang/words.txt  --keep_isymbols=false --keep_osymbols=false | \
    fstrmepsilon | fstarcsort --sort_type=ilabel > $outdir/lang_interp/G.fst

