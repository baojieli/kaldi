// ivector/energy-diarization.h

// Copyright  2013   Daniel Povey
//            2017   Matthew Maciejewski

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


#ifndef KALDI_IVECTOR_ENERGY_DIARIZATION_H_
#define KALDI_IVECTOR_ENERGY_DIARIZATION_H_

#include <cassert>
#include <cstdlib>
#include <string>
#include <vector>

#include "matrix/matrix-lib.h"
#include "util/common-utils.h"
#include "base/kaldi-error.h"

namespace kaldi {

/*
  Note: we may move the location of this file in the future, e.g. to feat/
  This code is geared toward speaker-id applications and is not suitable
  for automatic speech recognition (ASR) because it makes independent
  decisions for each frame without imposing any notion of continuity.
*/
 
struct EnergyDiarizationOptions {
  BaseFloat vad_energy_ratio_threshold;
  BaseFloat vad_energy_threshold;
  int32 vad_frames_context;
  BaseFloat vad_strong_proportion_threshold;
  BaseFloat vad_weak_proportion_threshold;
  
  EnergyDiarizationOptions(): vad_energy_ratio_threshold(0.9),
                              vad_energy_threshold(0.0),
                              vad_frames_context(0),
                              vad_strong_proportion_threshold(0.6),
                              vad_weak_proportion_threshold(0.6) { }
  void Register(OptionsItf *opts) {
    opts->Register("vad-energy-ratio-threshold", &vad_energy_ratio_threshold,
                   "Ratio of speech energy to exceed for main speaker to be"
                   "chosen");
    opts->Register("vad-energy-threshold", &vad_energy_threshold,
                   "Multiplier on min energy in window that must be exceeded "
                   "to be considered voiced");
    opts->Register("vad-frames-context", &vad_frames_context,
                   "Number of frames of context on each side of central frame, "
                   "in window for which energy is monitored");
    opts->Register("vad-strong-proportion-threshold", &vad_strong_proportion_threshold,
                   "Parameter controlling the proportion of frames within "
                   "the window that need to have more energy in the strong "
                   "source to accept");
    opts->Register("vad-weak-proportion-threshold", &vad_weak_proportion_threshold,
                   "Parameter controlling the proportion of frames within "
                   "the window that need to have more energy in the weak "
                   "source to reject");
  }
};


/// Compute voice-activity vector for a file: 1 if we judge the frame as
void ComputeEnergyDiarization(const EnergyDiarizationOptions &opts,
                              const MatrixBase<BaseFloat> &strong_features,
                              const MatrixBase<BaseFloat> &weak_features,
                              Vector<BaseFloat> *output_voiced);


}  // namespace kaldi



#endif  // KALDI_IVECTOR_ENERGY_DIARIZATION_H_
