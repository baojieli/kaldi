#!/bin/bash

ctm1=$1
ctm2=$2
ctm_out=$3

cat $ctm1 $ctm2 | awk -F'[. ]' '{printf("%s 1 %03d.%02d %03d.%02d %s\n",$1,$3,$4,$5,$6,$7)}' \
    | sort | awk -F'[. ]' '{printf("%s 1 %d.%02d %d.%02d %s\n",$1,$3,$4,$5,$6,$7)}' > $ctm_out
