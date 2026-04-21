#include "gn_native_audio_mix_chop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif
namespace godot {
void GNNativeAudioMixChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "inputs", "volumes", "pans", "master_vol"),
                         &GNNativeAudioMixChop::process);
}
PackedFloat32Array GNNativeAudioMixChop::process(const TypedArray<PackedFloat32Array> &inputs,
        const PackedFloat32Array &volumes, const PackedFloat32Array &pans, double master_vol) {
    int num_inputs = inputs.size();
    if (num_inputs == 0) return PackedFloat32Array();
    // Find max buffer size
    int max_sz = 0;
    for (int i = 0; i < num_inputs; ++i) {
        PackedFloat32Array arr = inputs[i];
        if (arr.size() > max_sz) max_sz = arr.size();
    }
    PackedFloat32Array out;
    out.resize(max_sz);
    float *op = out.ptrw();
    memset(op, 0, max_sz * sizeof(float));
    int frames = max_sz / 2;
    for (int inp = 0; inp < num_inputs; ++inp) {
        PackedFloat32Array arr = inputs[inp];
        const float *src = arr.ptr();
        int sz = arr.size();
        double vol = (inp < volumes.size()) ? (double)volumes[inp] : 1.0;
        double pan = (inp < pans.size()) ? (double)pans[inp] : 0.0;
        // Equal power pan
        double angle = (pan + 1.0) * 0.25 * M_PI;
        double gain_l = cos(angle) * vol;
        double gain_r = sin(angle) * vol;
        int inp_frames = sz / 2;
        for (int f = 0; f < frames && f < inp_frames; ++f) {
            op[f * 2] += src[f * 2] * (float)gain_l;
            op[f * 2 + 1] += src[f * 2 + 1] * (float)gain_r;
        }
    }
    // Master volume
    float mv = (float)master_vol;
    for (int i = 0; i < max_sz; ++i) op[i] *= mv;
    return out;
}
} // namespace godot
