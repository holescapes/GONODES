#include "gn_native_audio_envelope_chop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
namespace godot {
void GNNativeAudioEnvelopeChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "input", "attack", "release", "sr"),
                         &GNNativeAudioEnvelopeChop::process);
    ClassDB::bind_method(D_METHOD("reset"), &GNNativeAudioEnvelopeChop::reset);
}
void GNNativeAudioEnvelopeChop::reset() { _env[0] = _env[1] = 0.0; }
PackedFloat32Array GNNativeAudioEnvelopeChop::process(const PackedFloat32Array &input,
        double attack, double release, double sr) {
    int n = input.size();
    PackedFloat32Array out;
    out.resize(n);
    if (n == 0) return out;
    const float *ip = input.ptr();
    float *op = out.ptrw();
    int frames = n / 2;
    // Attack/release coefficients (exponential smoothing)
    double att_coeff = (attack > 0.0) ? exp(-1.0 / (attack * sr)) : 0.0;
    double rel_coeff = (release > 0.0) ? exp(-1.0 / (release * sr)) : 0.0;
    for (int s = 0; s < 2; ++s) {
        for (int f = 0; f < frames; ++f) {
            double abs_in = fabs((double)ip[f * 2 + s]);
            if (abs_in > _env[s]) {
                _env[s] = att_coeff * _env[s] + (1.0 - att_coeff) * abs_in;
            } else {
                _env[s] = rel_coeff * _env[s] + (1.0 - rel_coeff) * abs_in;
            }
            op[f * 2 + s] = (float)_env[s];
        }
    }
    return out;
}
} // namespace godot
