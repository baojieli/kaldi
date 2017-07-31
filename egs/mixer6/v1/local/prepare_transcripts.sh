#!/bin/bash

ctm_file=$1

. ./path.sh

ctm_dir=$(dirname $ctm_file)
mkdir -p $ctm_dir/alignments

for id in $(cat $ctm_file | awk -F'[ ]' '{print $1}' | uniq); do
  grep -e "$id" $ctm_file | awk '{print $3","$4","$5}' > $ctm_dir/alignments/$id.csv
done
