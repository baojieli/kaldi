#!/bin/bash

if [ $# != 1 ]; then
  echo "Usage: $0 <data-dir>"
  exit 1
fi

data=$1

[ ! -d $data ] && echo "$0: no such directory $data" && exit 1;

[ ! -f $data/utt2spk ] && echo "$0: no such file $data/utt2spk" && exit 1;
[ ! -f $data/segments ] && echo "$0: no such file $data/segments" && exit 1;

cut -d' ' -f2 $data/segments > $data/1.tmp
cut -d' ' -f2 $data/utt2spk > $data/2.tmp
paste -d' ' $data/1.tmp $data/2.tmp > $data/segutt2spk
rm $data/{1,2}.tmp
utils/utt2spk_to_spk2utt.pl $data/segutt2spk > $data/segspk2utt
