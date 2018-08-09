#!/bin/bash

if [ $# -ne 2 ]; then
  echo "Usage:"
  echo "$0 <json_file> <dir_out>"
  echo "Creates a data subdir for each microphone"
  exit
fi

json=$1
dir_out=$2

sess=$(head -n 45 $json | grep "session_id" | awk -F'"' '{print $4}')
num_IDs=$(head -n 25 $json | grep '[UP][0-9]' | awk -F'"' '{print $2}' | sort -u | wc -l)

mkdir -p $dir_out

grep '"speaker"\|\[redacted\]' $json | awk -F'"' '{print $4}' > $dir_out/speaker_IDs.txt

for ID in $(head -n 25 $json | grep '[UP][0-9]' | awk -F'"' '{print $2}' | sort -u); do
  mkdir -p $dir_out/$ID
  grep "start_time" -A $(($num_IDs+1)) $json | grep "$ID" | awk -F'[":]' '{print $5*3600+$6*60+$7}' > $dir_out/$ID/start_times.txt
  grep "end_time" -A $(($num_IDs+1)) $json | grep "$ID" | awk -F'[":]' '{print $5*3600+$6*60+$7}' > $dir_out/$ID/end_times.txt
  paste $dir_out/$ID/start_times.txt $dir_out/$ID/end_times.txt $dir_out/speaker_IDs.txt | awk -v sess="$sess" -v ID="$ID" '{printf("%s-%s_%s_%07d_%07d %s-%s %0.2f %0.2f\n", sess, ID, $3, $1*100, $2*100, sess, ID, $1, $2)}' > $dir_out/$ID/segments
  awk -F'[ _]' '{print $1"_"$2"_"$3"_"$4" "$2}' $dir_out/$ID/segments > $dir_out/$ID/utt2spk
done

paste $(head -n 25 $json | grep '[UP][0-9]' | awk -F'"' '{print $2}' | sort -u | sed "s@^@$dir_out/@g;s@\$@/start_times.txt@g") $dir_out/speaker_IDs.txt > $dir_out/start_times.txt
paste $(head -n 25 $json | grep '[UP][0-9]' | awk -F'"' '{print $2}' | sort -u | sed "s@^@$dir_out/@g;s@\$@/end_times.txt@g") $dir_out/speaker_IDs.txt > $dir_out/end_times.txt
declare -a speakers=($(head -n 25 $json | grep 'P[0-9]' | awk -F'"' '{print $2}' | sort -u))

num_spk=${#speakers[@]}
for (( i=1; i<${num_spk}+1; i++ )); do
  grep "${speakers[$i-1]}" $dir_out/start_times.txt | awk "{for (i=1; i<NF; i++) {printf(\"%0.2f\\t\",\$i-\$$i)}; printf(\"%s\\n\",\$NF)}" > $dir_out/${speakers[$i-1]}_map.tmp
  grep "_${speakers[$i-1]}_" $dir_out/${speakers[$i-1]}/segments | cut -d' ' -f1 | paste - $dir_out/${speakers[$i-1]}_map.tmp | rev | cut -f2- | rev > $dir_out/${speakers[$i-1]}_map.txt
done

line_one="segment"
for ID in $(head -n 25 $json | grep '[UP][0-9]' | awk -F'"' '{print $2}' | sort -u); do
  line_one="${line_one}@${ID}"
done
echo "$line_one" | sed -e 's/@/\t/g' > $dir_out/segment_drift_map.txt
cat $dir_out/P*_map.txt | sort -t_ -k3 >> $dir_out/segment_drift_map.txt

rm $dir_out/*.tmp
rm $dir_out/*_times.txt
rm $dir_out/P*.txt
rm $dir_out/*/*_times.txt
