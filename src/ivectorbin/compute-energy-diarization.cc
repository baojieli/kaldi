// ivectorbin/compute-energy-diarization.cc

// Copyright  2013  Daniel Povey

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
#include "ivector/energy-diarization.h"


int main(int argc, char *argv[]) {
  try {
    using namespace kaldi;
    using kaldi::int32;

    const char *usage =
        "This program reads input features and writes out, for each utterance,\n"
        "a vector of floats that are 1.0 if we judge the frame voice and 0.0\n"
        "otherwise.  The algorithm is very simple and is based on thresholding\n"
        "the log mel energy (and taking the consensus of threshold decisions\n"
        "within a window centered on the current frame).  See the options for\n"
        "more details, and egs/sid/s1/run.sh for examples; this program is\n"
        "intended for use in speaker-ID.\n"
        "\n"
        "Usage: compute-energy-diarization [options] <strong-feats-rspecifier> <weak-feats-rspecifier> <vad-wspecifier>\n"
        "e.g.: compute-energy-diarization scp:feats1.scp scp:feats2.scp ark:vad.ark\n";

    ParseOptions po(usage);
    bool omit_unvoiced_utts = false;
    po.Register("omit-unvoiced-utts", &omit_unvoiced_utts,
                "If true, do not write out voicing information for "
                "utterances that were judged 100% unvoiced.");
    EnergyDiarizationOptions opts;
    opts.Register(&po);
    po.Read(argc, argv);

    if (po.NumArgs() != 3) {
      po.PrintUsage();
      exit(1);
    }

    std::string strong_feat_rspecifier = po.GetArg(1);
    std::string weak_feat_rspecifier = po.GetArg(2);
    std::string vad_wspecifier = po.GetArg(3);

    SequentialBaseFloatMatrixReader strong_feat_reader(strong_feat_rspecifier);
    RandomAccessBaseFloatMatrixReader weak_feat_reader(weak_feat_rspecifier);
    BaseFloatVectorWriter vad_writer(vad_wspecifier);

    int32 num_done = 0, num_err = 0;
    int32 num_unvoiced = 0;
    double tot_length = 0.0, tot_decision = 0.0;

    for (;!strong_feat_reader.Done(); strong_feat_reader.Next()) {
      std::string utt = strong_feat_reader.Key();
      if (!weak_feat_reader.HasKey(utt)) {
        KALDI_WARN << "No weak feature matrix for utterance " << utt;
        num_err++;
        continue;
      }
      Matrix<BaseFloat> strong_feat(strong_feat_reader.Value());
      Matrix<BaseFloat> weak_feat(weak_feat_reader.Value(utt));
      if ((strong_feat.NumRows() == 0) || (weak_feat.NumRows() == 0)) {
        KALDI_WARN << "Empty feature matrix for utterance " << utt;
        num_err++;
        continue;
      }
      Vector<BaseFloat> vad_result(strong_feat.NumRows());

      ComputeEnergyDiarization(opts, strong_feat, weak_feat, &vad_result);

      double sum = vad_result.Sum();
      if (sum == 0.0) {
        KALDI_WARN << "No frames were judged voiced for utterance " << utt;
        num_unvoiced++;
      } else {
        num_done++;
      }
      tot_decision += vad_result.Sum();
      tot_length += vad_result.Dim();

      if (!(omit_unvoiced_utts && sum == 0)) {
        vad_writer.Write(utt, vad_result);
      }
    }

    KALDI_LOG << "Applied energy based voice activity detection; "
              << "processed " << num_done << " utterances successfully; "
              << num_err << " had empty features, and " << num_unvoiced
              << " were completely unvoiced.";
    KALDI_LOG << "Proportion of voiced frames was "
              << (tot_decision / tot_length) << " over "
              << tot_length << " frames.";
    return (num_done != 0 ? 0 : 1);
  } catch(const std::exception &e) {
    std::cerr << e.what();
    return -1;
  }
}
