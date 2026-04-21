#include "gn_native_audio_pitch_chop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cstring>
#include <cmath>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif
namespace godot {
void GNNativeAudioPitchChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "input", "pitch_shift", "grain_size", "sr"),
                         &GNNativeAudioPitchChop::process);
    ClassDB::bind_method(D_METHOD("reset"), &GNNativeAudioPitchChop::reset);
}
void GNNativeAudioPitchChop::reset() {
    _initialized = false;
    for (int s = 0; s < 2; ++s) { _grain_buf[s].clear(); _grain_pos[s] = 0; }
}
PackedFloat32Array GNNativeAudioPitchChop::process(const PackedFloat32Array &input,
        double pitch_shift, int grain_size, double sr) {
    int n = input.size();
    PackedFloat32Array out;
    out.resize(n);
    if (n == 0 || pitch_shift <= 0.0) {
        memcpy(out.ptrw(), input.ptr(), n * sizeof(float));
        return out;
    }
    // Simple granular pitch shifting
    int frames = n / 2;
    if (!_initialized || sr != _last_sr) {
        for (int s = 0; s < 2; ++s) {
            _grain_buf[s].assign(grain_size * 4, 0.0f);
            _grain_pos[s] = 0;
        }
        _last_sr = sr;
        _initialized = true;
    }
    const float *ip = input.ptr();
    float *op = out.ptrw();
    int half_grain = grain_size / 2;
    if (half_grain < 1) half_grain = 1;
    for (int s = 0; s < 2; ++s) {
        int buf_sz = (int)_grain_buf[s].size();
        // Store input into circular buffer
        for (int f = 0; f < frames; ++f) {
            _grain_buf[s][_grain_pos[s]] = ip[f * 2 + s];
            _grain_pos[s] = (_grain_pos[s] + 1) % buf_sz;
        }
        // Read from buffer at shifted rate
        double read_pos = (double)(_grain_pos[s] - frames);
        if (read_pos < 0) read_pos += buf_sz;
        for (int f = 0; f < frames; ++f) {
            int idx0 = ((int)read_pos) % buf_sz;
            if (idx0 < 0) idx0 += buf_sz;
            int idx1 = (idx0 + 1) % buf_sz;
            double frac = read_pos - floor(read_pos);
            float sample = _grain_buf[s][idx0] * (float)(1.0 - frac)
                          + _grain_buf[s][idx1] * (float)frac;
            // Hann window for grain overlap
            double grain_phase = fmod((double)f / (double)half_grain, 2.0);
            double window = 0.5 * (1.0 - cos(M_PI * (grain_phase < 1.0 ? grain_phase : 2.0 - grain_phase)));
            op[f * 2 + s] = sample * (float)window;
            read_pos += pitch_shift;
            if (read_pos >= buf_sz) read_pos -= buf_sz;
            if (read_pos < 0) read_pos += buf_sz;
        }
    }
    return out;
}
} // namespace godot
