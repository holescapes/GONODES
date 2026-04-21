#include "gn_native_audio_delay_chop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cstring>
#include <cmath>
namespace godot {
void GNNativeAudioDelayChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "input", "delay_time", "feedback", "wet", "dry", "max_delay", "sr"),
                         &GNNativeAudioDelayChop::process);
    ClassDB::bind_method(D_METHOD("reset"), &GNNativeAudioDelayChop::reset);
}
void GNNativeAudioDelayChop::reset() {
    _initialized = false;
    for (int s = 0; s < 2; ++s) { _buf[s].clear(); _write_idx[s] = 0; }
}
PackedFloat32Array GNNativeAudioDelayChop::process(const PackedFloat32Array &input,
        double delay_time, double feedback, double wet, double dry,
        double max_delay, double sr) {
    int n = input.size();
    PackedFloat32Array out;
    out.resize(n);
    if (n == 0) return out;
    if (!_initialized || sr != _last_sr || max_delay != _last_max_delay) {
        int buf_sz = (int)(max_delay * sr) + 1;
        if (buf_sz < 1) buf_sz = 1;
        for (int s = 0; s < 2; ++s) {
            _buf[s].assign(buf_sz, 0.0f);
            _write_idx[s] = 0;
        }
        _last_sr = sr; _last_max_delay = max_delay;
        _initialized = true;
    }
    const float *ip = input.ptr();
    float *op = out.ptrw();
    int frames = n / 2;
    int delay_samples = (int)(delay_time * sr);
    for (int f = 0; f < frames; ++f) {
        for (int s = 0; s < 2; ++s) {
            int buf_sz = (int)_buf[s].size();
            if (delay_samples >= buf_sz) delay_samples = buf_sz - 1;
            if (delay_samples < 0) delay_samples = 0;
            int read_idx = (_write_idx[s] - delay_samples + buf_sz) % buf_sz;
            float delayed = _buf[s][read_idx];
            float in_sample = ip[f * 2 + s];
            _buf[s][_write_idx[s]] = in_sample + delayed * (float)feedback;
            _write_idx[s] = (_write_idx[s] + 1) % buf_sz;
            op[f * 2 + s] = in_sample * (float)dry + delayed * (float)wet;
        }
    }
    return out;
}
} // namespace godot
