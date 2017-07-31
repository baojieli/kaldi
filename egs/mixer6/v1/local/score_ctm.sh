#!/bin/bash

ref_ctm=$1
script_dir=$2
dec_ctm=$3
out_dir=$4

mkdir -p $out_dir

cmd="grep"
for id in $(cat $ref_ctm | awk '{print $1}' | uniq); do
  cmd="$cmd -e $id"
done

$cmd $dec_ctm > filt_dec.ctm

cat $ref_ctm | awk '{print $1" A "$3" "$4" "$5}' > ref_full.ctm
grep -e ' A ' $ref_ctm | awk '{print $1" A "$3" "$4" "$5}' > ref_script.ctm
grep -e ' B ' $ref_ctm | awk '{print $1" A "$3" "$4" "$5}' > ref_off.ctm
sclite -r ref_full.ctm ctm -h filt_dec.ctm ctm > $out_dir/score_full.txt
sclite -r ref_script.ctm ctm -h filt_dec.ctm ctm > $out_dir/score_script.txt
sclite -r ref_off.ctm ctm -h filt_dec.ctm ctm > $out_dir/score_off.txt

rm filt_dec.ctm
rm ref_{full,script,off}.ctm

rm -f temp_{ref,hyp}.txt

for id in $(cat $dec_ctm | awk '{print $1}' | uniq); do
  line=$(grep -e "$id" $dec_ctm | awk '{print $5}' | tr '\n' ' ' | sed -e 's/ha //g' | sed -e 's/\[noise\] //g' | sed -e 's/\[laughter\] //g')
  line+=" (${id}_1)"
  echo $line >> temp_hyp.txt
  ref=$(echo $id | sed -e 's/[0-9]*//g')
  line=$(cat $script_dir/$ref.txt | tr '\n' ' ' | sed -e 's/ha //g')
  line+=" (${id}_1)"
  echo $line >> temp_ref.txt
done

sclite -r temp_ref.txt trn -h temp_hyp.txt trn -i rm > $out_dir/scores.txt

rm temp_{ref,hyp}.txt
