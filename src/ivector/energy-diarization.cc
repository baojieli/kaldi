// ivector/energy-diarization.cc

// Copyright     2013  Daniel Povey
//               2017  Matthew Maciejwski

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


#include "ivector/energy-diarization.h"
#include "matrix/matrix-functions.h"


namespace kaldi {

void ComputeEnergyDiarization(const EnergyDiarizationOptions &opts,
                              const MatrixBase<BaseFloat> &strong_feats,
                              const MatrixBase<BaseFloat> &weak_feats,
                              Vector<BaseFloat> *output_voiced) {
  int32 T = strong_feats.NumRows();
  output_voiced->Resize(T);
  if (T == 0) {
    KALDI_WARN << "Empty features";
    return;
  }
  if (T != weak_feats.NumRows()) {
    KALDI_WARN << "Strong and weak feature lengths do not match";
    return;
  }
  Vector<BaseFloat> strong_log_energy(T);
  Vector<BaseFloat> weak_log_energy(T);
  strong_log_energy.CopyColFromMat(strong_feats, 0); // column zero is log-energy.
  weak_log_energy.CopyColFromMat(weak_feats, 0);
  
  BaseFloat energy_ratio_threshold = opts.vad_energy_ratio_threshold;
  
  KALDI_ASSERT(opts.vad_frames_context >= 0);
  KALDI_ASSERT(opts.vad_proportion_threshold > 0.0 &&
               opts.vad_proportion_threshold < 1.0);
  for (int32 t = 0; t < T; t++) {
    const BaseFloat *strong_log_energy_data = strong_log_energy.Data();
    const BaseFloat *weak_log_energy_data = weak_log_energy.Data();
    int32 num_count = 0, den_count = 0, context = opts.vad_frames_context;
    for (int32 t2 = t - context; t2 <= t + context; t2++) {
      if (t2 >= 0 && t2 < T) {
        den_count++;
        if (strong_log_energy_data[t2] - weak_log_energy_data[t2] > Log(energy_ratio_threshold))
          num_count++;
      }
    }
    if (num_count >= den_count * opts.vad_proportion_threshold)
      (*output_voiced)(t) = 1.0;
    else
      (*output_voiced)(t) = 0.0;
  }
}  

}
