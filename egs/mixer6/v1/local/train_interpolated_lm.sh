#!/bin/bash

set -e -o pipefail

. ./path.sh

transcripts=/home/mmaciej2/Kaldi2/kaldi-current/egs/blip/v1/data/local/transcripts/hand-transcripts/text_all_transcripts

if [ 0 == 1 ]; then
## train independent LMs
local/train_lms_srilm_2g.sh --train-text aspire_models/text data/ data/aspire_lm
local/train_lms_srilm_5g.sh --train-text data/local/transcripts/text_all_books.txt \
    --dev-text data/local/transcripts/text_all_books.txt data/ data/books_lm

## interpolate LMs
# note: lms were selected manually
mkdir -p data/interp_lm
for w in 0.9 0.905 0.91; do
    ngram -lm data/books_lm/lm.gz  -mix-lm data/aspire_lm/lm.gz \
          -lambda $w -write-lm data/interp_lm/lm.${w}.gz
    echo -n "data/interp_lm/lm.${w}.gz "
    ngram -lm data/interp_lm/lm.${w}.gz -ppl $transcripts | paste -s
done | sort  -k15,15g  > data/interp_lm/perplexities.txt
fi

# manually picked through iterative runs on LM weights
lm=data/interp_lm/lm.0.9.gz

mkdir -p data/lang_interp
cp -r data/lang/{L.fst,L_disambig.fst,phones,phones.txt,words.txt} data/lang_interp/

gunzip -c "$lm" | \
   grep -v '<s> <s>' | \
   grep -v '</s> <s>' | \
   grep -v '</s> </s>' | \
   arpa2fst - | fstprint | \
   utils/remove_oovs.pl /dev/null | \
   utils/eps2disambig.pl | utils/s2eps.pl | fstcompile --isymbols=data/lang/words.txt \
     --osymbols=data/lang/words.txt  --keep_isymbols=false --keep_osymbols=false | \
    fstrmepsilon | fstarcsort --sort_type=ilabel > data/lang_interp/G.fst

