#!/bin/bash

set -e -o pipefail

. ./path.sh

trn=$1
indir=$2
outdir=$3

cat $trn | awk '{print "<text> "$0}' > text.tmp

local/train_lms_srilm_5g.sh --train-text text.tmp --dev-text text.tmp \
    data $outdir/lm

lm=$(head -n 1 $outdir/lm/perplexities.txt | awk '{print $1}')

mkdir -p $outdir/lang
cp -r $indir/{L.fst,L_disambig.fst,phones,phones.txt,words.txt} $outdir/lang

gunzip -c "$lm" | \
   grep -v '<s> <s>' | \
   grep -v '</s> <s>' | \
   grep -v '</s> </s>' | \
   arpa2fst - | fstprint | \
   utils/remove_oovs.pl /dev/null | \
   utils/eps2disambig.pl | utils/s2eps.pl | fstcompile --isymbols=$indir/words.txt \
     --osymbols=$indir/words.txt  --keep_isymbols=false --keep_osymbols=false | \
    fstrmepsilon | fstarcsort --sort_type=ilabel > $outdir/lang/G.fst

rm -f text.tmp
