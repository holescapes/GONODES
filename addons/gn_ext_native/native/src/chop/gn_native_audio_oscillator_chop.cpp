#include "gn_native_audio_oscillator_chop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif
namespace godot {
void GNNativeAudioOscillatorChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process_stereo", "waveform", "freq", "amp", "pw",
                                  "fm_depth", "stereo_phase", "buffer_size",
                                  "sample_rate", "fm_input"),
                         &GNNativeAudioOscillatorChop::process_stereo);
    ClassDB::bind_method(D_METHOD("reset"), &GNNativeAudioOscillatorChop::reset);
}
void GNNativeAudioOscillatorChop::reset() { _phase_l = _phase_r = 0.0; }

static inline float gen_wave(int waveform, double phase, double pw) {
    double p = fmod(phase, 1.0);
    if (p < 0.0) p += 1.0;
    switch (waveform) {
        case 0: return (float)sin(p * 2.0 * M_PI);
        case 1: return p < pw ? 1.0f : -1.0f;
        case 2: return (float)(2.0 * p - 1.0);
        case 3: return (float)(p < 0.5 ? 4.0 * p - 1.0 : 3.0 - 4.0 * p);
        default: return (float)sin(p * 2.0 * M_PI);
    }
}

PackedFloat32Array GNNativeAudioOscillatorChop::process_stereo(
        int waveform, double freq, double amp, double pw, double fm_depth,
        double stereo_phase, int buffer_size, double sample_rate,
        const PackedFloat32Array &fm_input) {
    PackedFloat32Array out;
    out.resize(buffer_size * 2);
    float *op = out.ptrw();
    const float *fm = fm_input.ptr();
    int fm_sz = fm_input.size();
    double inc = freq / sample_rate;
    for (int i = 0; i < buffer_size; ++i) {
        double fm_mod = (i < fm_sz) ? (double)fm[i] * fm_depth : 0.0;
        double phase_inc = inc + fm_mod / sample_rate;
        _phase_l += phase_inc;
        _phase_r = _phase_l + stereo_phase;
        op[i * 2] = gen_wave(waveform, _phase_l, pw) * (float)amp;
        op[i * 2 + 1] = gen_wave(waveform, _phase_r, pw) * (float)amp;
    }
    _phase_l = fmod(_phase_l, 1.0);
    return out;
}
} // namespace godot
