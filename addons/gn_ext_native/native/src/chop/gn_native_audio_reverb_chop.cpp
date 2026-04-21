#include "gn_native_audio_reverb_chop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cstring>
#include <cmath>
namespace godot {
void GNNativeAudioReverbChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "input", "room_size", "damping", "wet", "dry", "sr"),
                         &GNNativeAudioReverbChop::process);
    ClassDB::bind_method(D_METHOD("reset"), &GNNativeAudioReverbChop::reset);
}
void GNNativeAudioReverbChop::reset() {
    _initialized = false;
    for (int c = 0; c < NUM_COMBS; ++c) for (int s = 0; s < 2; ++s) { _comb_buf[c][s].clear(); _comb_idx[c][s] = 0; }
    for (int a = 0; a < NUM_APS; ++a) for (int s = 0; s < 2; ++s) { _ap_buf[a][s].clear(); _ap_idx[a][s] = 0; }
}
void GNNativeAudioReverbChop::_init_buffers(double sr) {
    // Schroeder reverb delay lengths, scaled by sample rate
    static const int comb_delays_44k[NUM_COMBS] = {1557, 1617, 1491, 1422};
    static const int ap_delays_44k[NUM_APS] = {225, 556};
    double scale = sr / 44100.0;
    for (int c = 0; c < NUM_COMBS; ++c) {
        int sz = (int)(comb_delays_44k[c] * scale);
        if (sz < 1) sz = 1;
        for (int s = 0; s < 2; ++s) {
            _comb_buf[c][s].assign(sz, 0.0f);
            _comb_idx[c][s] = 0;
        }
    }
    for (int a = 0; a < NUM_APS; ++a) {
        int sz = (int)(ap_delays_44k[a] * scale);
        if (sz < 1) sz = 1;
        for (int s = 0; s < 2; ++s) {
            _ap_buf[a][s].assign(sz, 0.0f);
            _ap_idx[a][s] = 0;
        }
    }
    _last_sr = sr;
    _initialized = true;
}
PackedFloat32Array GNNativeAudioReverbChop::process(const PackedFloat32Array &input,
        double room_size, double damping, double wet, double dry, double sr) {
    int n = input.size();
    PackedFloat32Array out;
    out.resize(n);
    if (n == 0) return out;
    if (!_initialized || sr != _last_sr) _init_buffers(sr);
    const float *ip = input.ptr();
    float *op = out.ptrw();
    int frames = n / 2;
    double feedback = room_size * 0.9 + 0.1;
    double damp = damping;
    for (int f = 0; f < frames; ++f) {
        for (int s = 0; s < 2; ++s) {
            float in_sample = ip[f * 2 + s];
            float reverb = 0.0f;
            // Comb filters in parallel
            for (int c = 0; c < NUM_COMBS; ++c) {
                float *buf = _comb_buf[c][s].data();
                int sz = (int)_comb_buf[c][s].size();
                int &idx = _comb_idx[c][s];
                float delayed = buf[idx];
                reverb += delayed;
                float filtered = delayed * (1.0f - (float)damp) + buf[(idx + sz - 1) % sz] * (float)damp;
                buf[idx] = in_sample + filtered * (float)feedback;
                idx = (idx + 1) % sz;
            }
            reverb /= (float)NUM_COMBS;
            // Allpass filters in series
            for (int a = 0; a < NUM_APS; ++a) {
                float *buf = _ap_buf[a][s].data();
                int sz = (int)_ap_buf[a][s].size();
                int &idx = _ap_idx[a][s];
                float delayed = buf[idx];
                float out_ap = -reverb + delayed;
                buf[idx] = reverb + delayed * 0.5f;
                reverb = out_ap;
                idx = (idx + 1) % sz;
            }
            op[f * 2 + s] = in_sample * (float)dry + reverb * (float)wet;
        }
    }
    return out;
}
} // namespace godot
