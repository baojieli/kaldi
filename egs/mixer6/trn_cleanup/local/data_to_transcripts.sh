#!/bin/bash

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <data-dir> <trn-dir>"
  exit
fi

data=$1
trn=$2

mkdir -p $trn

for id in $(cat $data/wav.scp | awk '{print $1}'); do
  grep -e "$id" $data/segments | awk '{print $3","$4}' > 1.tmp
  grep -e "$id" $data/text | cut -f 1 -d ' ' --complement | tr '[:lower:]' '[:upper:]' > 2.tmp
  paste -d ',' 1.tmp 2.tmp > $trn/$id.txt
done
