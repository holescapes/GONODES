#include "gn_native_wave_chop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeWaveChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "wave_type", "num_channels",
                                  "sample_length", "frequency", "amplitude",
                                  "offset", "phase", "phase_step", "elapsed_time"),
                         &GNNativeWaveChop::process);
}

static double _evaluate_wave(int wave_type, double phase) {
    switch (wave_type) {
        case 0: return std::sin(phase * Math_TAU);
        case 1: return 1.0 - 4.0 * std::fabs(phase - 0.5);
        case 2: return phase < 0.5 ? 1.0 : -1.0;
        case 3: return 2.0 * phase - 1.0;
        case 4: return phase < 0.25 ? 1.0 : 0.0;
        case 5: return phase;
        default: return 0.0;
    }
}

Dictionary GNNativeWaveChop::process(int wave_type, int num_channels,
                                      int sample_length, double frequency,
                                      double amplitude, double offset,
                                      double phase, double phase_step,
                                      double elapsed_time) {
    Dictionary out;
    for (int ch = 0; ch < num_channels; ++ch) {
        String ch_name = "chan" + String::num_int64(ch + 1);
        double ch_phase = phase + phase_step * ch;

        PackedFloat32Array samples;
        if (sample_length <= 1) {
            samples.resize(1);
            double pv = std::fmod(elapsed_time * frequency + ch_phase, 1.0);
            if (pv < 0.0) pv += 1.0;
            samples.set(0, (float)(_evaluate_wave(wave_type, pv) * amplitude + offset));
        } else {
            samples.resize(sample_length);
            float *buf = samples.ptrw();
            for (int i = 0; i < sample_length; ++i) {
                double norm = (double)i / (double)sample_length;
                double pv = std::fmod(norm * frequency + ch_phase, 1.0);
                if (pv < 0.0) pv += 1.0;
                buf[i] = (float)(_evaluate_wave(wave_type, pv) * amplitude + offset);
            }
        }
        out[ch_name] = samples;
    }
    return out;
}

} // namespace godot
