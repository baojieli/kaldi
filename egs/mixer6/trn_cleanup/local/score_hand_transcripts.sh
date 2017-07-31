#!/bin/bash

if [ $# -lt "3" ]; then
  echo "Usage: $0 <ref_dir> <hyp1> <hyp2> ... <out_dir>"
  exit
fi

ref_dir=$1
len=$(($#-2))
hyps=${@:2:$len}
out_dir=${@: -1}

mkdir -p $out_dir

rm -f temp_{ref,hyp}.txt

for elem in $hyps; do
  ref=$(echo $(basename $elem) | sed -e 's/[0-9]*//g')
  line=$(cat $ref_dir/$ref | tr '\n' ' ')
  line+=" ($(basename $elem)_1)"
  echo $line >> temp_ref.txt
  line=$(cat $elem | tr '\n' ' ')
  line+=" ($(basename $elem)_1)"
  echo $line >> temp_hyp.txt
done

sclite -r temp_ref.txt trn -h temp_hyp.txt trn -i rm > $out_dir/score.txt


rm -f temp_{ref,hyp}.txt

for elem in $hyps; do
  ref=$(echo $(basename $elem) | sed -e 's/[0-9]*//g')
  line=$(cat $ref_dir/$ref | tr '\n' ' ' | sed -e 's/ ha//g')
  line+=" ($(basename $elem)_1)"
  echo $line >> temp_ref.txt
  line=$(cat $elem | tr '\n' ' ' | sed -e 's/ ha//g')
  line+=" ($(basename $elem)_1)"
  echo $line >> temp_hyp.txt
done

sclite -r temp_ref.txt trn -h temp_hyp.txt trn -i rm > $out_dir/score_no_laughter.txt

rm temp_{ref,hyp}.txt

