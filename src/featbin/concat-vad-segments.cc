// featbin/concat-feat-segments.cc

// Copyright 2013 Johns Hopkins University (Author: Daniel Povey)
//           2015 Tom Ko
//           2017 Matthew Maciejewski

// See ../../COPYING for clarification regarding multiple authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
// THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
// WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
// MERCHANTABLITY OR NON-INFRINGEMENT.
// See the Apache 2 License for the specific language governing permissions and
// limitations under the License.


#include "base/kaldi-common.h"
#include "util/common-utils.h"
#include "matrix/kaldi-matrix.h"

namespace kaldi {

/*
   This function concatenates several sets of feature vectors
   to form a longer set. The length of the output will be equal
   to the sum of lengths of the inputs but the dimension will be
   the same to the inputs.
*/

void ConcatFeats(const std::vector<Vector<BaseFloat> > &in,
                 Vector<BaseFloat> *out) {
  KALDI_ASSERT(in.size() >= 1);
  int32 tot_len = in[0].Dim();
  for (int32 i = 1; i < in.size(); i++) {
    tot_len += in[i].Dim();
  }
  out->Resize(tot_len);
  int32 len_offset = 0;
  for (int32 i = 0; i < in.size(); i++) {
    int32 this_len = in[i].Dim();
    out->Range(len_offset, this_len).CopyFromVec(
        in[i]);
    len_offset += this_len;
  }
}


}

int main(int argc, char *argv[]) {
  try {
    using namespace kaldi;
    using namespace std;

    const char *usage =
        "Concatenate feature files of segments for a recording,\n"
        "so the output file has the sum of the num-frames of the inputs.\n"
        "Usage: concat-feat-segments <in-rspecifier> <segments-rxfilename> <out-wspecifier>\n"
        " e.g. concat-feat-segments scp:vad.scp segments ark,scp:full_vad.ark,full_vad.scp\n"
        "See also: copy-feats, append-vector-to-feats, paste-feats\n";

    ParseOptions po(usage);

    bool binary = true;
    po.Register("binary", &binary, "If true, output files in binary "
                "(only relevant for single-file operation, i.e. no tables)");

    po.Read(argc, argv);

    if (po.NumArgs() != 3) {
      po.PrintUsage();
      exit(1);
    }

    std::string feats_rspecifier = po.GetArg(1);
    std::string segments_rxfilename = po.GetArg(2);
    std::string feats_wspecifier = po.GetArg(3);

    RandomAccessBaseFloatVectorReader feat_reader(feats_rspecifier);
    Input segments(segments_rxfilename);
    BaseFloatVectorWriter feats_writer(feats_wspecifier);

    map<std::string, std::vector<std::string> > utt2segs;

    std::string line;
    while (std::getline(segments.Stream(),line)) {
      std::vector<std::string> split_line;
      SplitStringToVector(line, " \t\r", true, &split_line);
      if (split_line.size() != 4 && split_line.size() != 5) {
        KALDI_WARN << "Invalid line in segments file: " << line;
        continue;
      }
      utt2segs[split_line[1]].push_back(split_line[0]);
    }

    for (map<std::string, std::vector<std::string> >::const_iterator iter = utt2segs.begin();
         iter != utt2segs.end(); ++iter) {
      std::vector<Vector<BaseFloat> > feats(iter->second.size());
      for (int32 i = 0; i < iter->second.size(); i++) {
        feats[i] = feat_reader.Value(iter->second[i]);
      }
      Vector<BaseFloat> output;
      ConcatFeats(feats, &output);
      feats_writer.Write(iter->first, output);
    }

//    std::vector<Matrix<BaseFloat> > feats(po.NumArgs() - 1);
//    for (int32 i = 1; i < po.NumArgs(); i++)
//      ReadKaldiObject(po.GetArg(i), &(feats[i-1]));
//    Matrix<BaseFloat> output;
//    ConcatFeats(feats, &output);
//    std::string output_wxfilename = po.GetArg(po.NumArgs());
//    WriteKaldiObject(output, output_wxfilename, binary);

    // This will tend to produce too much output if we have a logging mesage.
    // KALDI_LOG << "Wrote concatenated features to " << output_wxfilename;
    return 0;
  } catch(const std::exception &e) {
    std::cerr << e.what();
    return -1;
  }
}
