#include "gn_native_audio_gate_chop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
namespace godot {
void GNNativeAudioGateChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "input", "threshold", "attack", "release",
                                  "range_db", "hold_time", "sr"),
                         &GNNativeAudioGateChop::process);
    ClassDB::bind_method(D_METHOD("reset"), &GNNativeAudioGateChop::reset);
}
void GNNativeAudioGateChop::reset() {
    for (int s = 0; s < 2; ++s) { _env[s] = 0.0; _gate_open[s] = false; }
}
PackedFloat32Array GNNativeAudioGateChop::process(const PackedFloat32Array &input,
        double threshold, double attack, double release, double range_db,
        double hold_time, double sr) {
    int n = input.size();
    PackedFloat32Array out;
    out.resize(n);
    if (n == 0) return out;
    const float *ip = input.ptr();
    float *op = out.ptrw();
    int frames = n / 2;
    double thresh_lin = pow(10.0, threshold / 20.0);
    double range_lin = pow(10.0, range_db / 20.0);
    double att_coeff = (attack > 0.0) ? exp(-1.0 / (attack * sr)) : 0.0;
    double rel_coeff = (release > 0.0) ? exp(-1.0 / (release * sr)) : 0.0;
    for (int s = 0; s < 2; ++s) {
        for (int f = 0; f < frames; ++f) {
            double abs_in = fabs((double)ip[f * 2 + s]);
            // Envelope follower
            if (abs_in > _env[s])
                _env[s] = att_coeff * _env[s] + (1.0 - att_coeff) * abs_in;
            else
                _env[s] = rel_coeff * _env[s] + (1.0 - rel_coeff) * abs_in;
            // Gate decision
            double gain;
            if (_env[s] >= thresh_lin) {
                gain = 1.0;
                _gate_open[s] = true;
            } else {
                gain = range_lin;
                _gate_open[s] = false;
            }
            op[f * 2 + s] = ip[f * 2 + s] * (float)gain;
        }
    }
    return out;
}
} // namespace godot
