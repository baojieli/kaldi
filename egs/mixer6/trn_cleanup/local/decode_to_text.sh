#!/bin/bash

. path.sh

if [ $# -ne 5 ]; then
  echo "Usage: $0 <data-dir> <lang-dir> <decode-dir> <trn-dir> <data-dir-out>"
  exit 1;
fi

datadir=$1
langdir=$2
decodedir=$3
trndir=$4
newdir=$5

rm -rf $newdir
mkdir -p $newdir

lat_files=`eval "echo $decodedir/lat.*.gz"`

lattice-scale --inv-acoustic-scale=10 "ark:gunzip -c $lat_files|" ark:- |\
    lattice-best-path --word-symbol-table=$langdir/words.txt ark:- ark,t:- 2>/dev/null |\
    utils/int2sym.pl -f 2- $langdir/words.txt > 1.tra

rm -f text.tmp
for id in $(cat $datadir/wav.scp | awk '{print $1}'); do
  echo -n "key1" > tra_all_text.txt
  grep -e "$id" 1.tra | awk '{$1=""; printf "%s", $0}' >> tra_all_text.txt
  grep -e "$id" 1.tra | awk '{print $1" "NF-1}' > seg_word_counts.txt

  echo -n "key1" > scr_all_text.txt
  cat $trndir/${id}.txt | awk '{printf " %s", $0}' >> scr_all_text.txt

  align-text ark:tra_all_text.txt ark:scr_all_text.txt ark,t:aligned_text.txt 2>/dev/null
  sed -i -e 's/key1 //g' aligned_text.txt
  sed -i -e 's/ ; /\n/g' aligned_text.txt

  cat $trndir/${id}.txt | sed -e 's/ /\n/g' > script.txt
  sed -i -e '/^ *$/d' script.txt

  python local/decode_to_text_helper.py seg_word_counts.txt aligned_text.txt script.txt >> text.tmp
done

cat text.tmp | awk '{if(NF>1){print $0}}' > $newdir/text
cat $newdir/text | awk '{print $1}' > ids.tmp
grep -f "ids.tmp" $datadir/segments > $newdir/segments
cp $datadir/wav.scp $newdir/
cat $newdir/segments | awk '{print $1" "$2}' > $newdir/utt2spk

utils/fix_data_dir.sh $newdir

#rm {1.tra,tra_all_text.txt,seg_word_counts.txt,scr_all_text.txt,aligned_text.txt,script.txt,text.tmp,ids.tmp}
