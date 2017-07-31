// featbin/concat-feat-spk-segments.cc

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

void ConcatFeats(const std::vector<Matrix<BaseFloat> > &in,
                 Matrix<BaseFloat> *out) {
  KALDI_ASSERT(in.size() >= 1);
  int32 tot_len = in[0].NumRows(),
      dim = in[0].NumCols();
  for (int32 i = 1; i < in.size(); i++) {
    KALDI_ASSERT(in[i].NumCols() == dim);
    tot_len += in[i].NumRows();
  }
  out->Resize(tot_len, dim);
  int32 len_offset = 0;
  for (int32 i = 0; i < in.size(); i++) {
    int32 this_len = in[i].NumRows();
    out->Range(len_offset, this_len, 0, dim).CopyFromMat(
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
        "Concatenate feature files of segments for a speaker,\n"
        "so the output file has the sum of the num-frames of the inputs.\n"
        "Usage: concat-feat-spk-segments <in-rspecifier> <spk2utt-rxfilename> <out-wspecifier>\n"
        " e.g. concat-feat-spk-segments feats.scp spk2utt ark,scp:full_feats.ark,full_feats.scp\n"
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
    std::string spk2utt_rxfilename = po.GetArg(2);
    std::string feats_wspecifier = po.GetArg(3);

    RandomAccessBaseFloatMatrixReader feat_reader(feats_rspecifier);
    Input spk2utt(spk2utt_rxfilename);
    BaseFloatMatrixWriter feats_writer(feats_wspecifier);

    std::string line;
    while (std::getline(spk2utt.Stream(),line)) {
      std::vector<std::string> split_line;
      SplitStringToVector(line, " \t\r", true, &split_line);
      if (split_line.size() < 2) {
        KALDI_WARN << "Invalid line in spk2utt file: " << line;
        continue;
      }
      std::vector<Matrix<BaseFloat> > feats(split_line.size()-1);
      for (int32 i = 0; i < split_line.size()-1; i++) {
        feats[i] = feat_reader.Value(split_line[i+1]);
      }
      Matrix<BaseFloat> output;
      ConcatFeats(feats, &output);
      feats_writer.Write(split_line[0], output);
    }
    return 0;
  } catch(const std::exception &e) {
    std::cerr << e.what();
    return -1;
  }
}
