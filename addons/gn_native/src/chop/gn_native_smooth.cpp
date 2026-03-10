#include "gn_native_smooth.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <cmath>

namespace godot {

void GNNativeSmooth::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "channels", "filter_type", "cutoff", "q", "reset"),
                         &GNNativeSmooth::process);
    ClassDB::bind_method(D_METHOD("clear_state"), &GNNativeSmooth::clear_state);
}

void GNNativeSmooth::clear_state() {
    _state.clear();
}

Dictionary GNNativeSmooth::process(const Dictionary &channels, int filter_type,
                                    double cutoff, double q, bool reset) {
    if (reset) _state.clear();

    // Clamp parameters
    double fc = CLAMP(cutoff, 0.001, 0.499); // normalized frequency (0..0.5)
    double Q = CLAMP(q, 0.1, 20.0);

    // Compute biquad coefficients (Butterworth-style)
    double w0 = 2.0 * Math_PI * fc;
    double alpha = std::sin(w0) / (2.0 * Q);
    double cos_w0 = std::cos(w0);

    double b0, b1, b2, a0, a1, a2;
    switch (filter_type) {
        case 0: // Low-pass
            b0 = (1.0 - cos_w0) / 2.0;
            b1 = 1.0 - cos_w0;
            b2 = (1.0 - cos_w0) / 2.0;
            a0 = 1.0 + alpha;
            a1 = -2.0 * cos_w0;
            a2 = 1.0 - alpha;
            break;
        case 1: // High-pass
            b0 = (1.0 + cos_w0) / 2.0;
            b1 = -(1.0 + cos_w0);
            b2 = (1.0 + cos_w0) / 2.0;
            a0 = 1.0 + alpha;
            a1 = -2.0 * cos_w0;
            a2 = 1.0 - alpha;
            break;
        case 2: // Band-pass
            b0 = alpha;
            b1 = 0.0;
            b2 = -alpha;
            a0 = 1.0 + alpha;
            a1 = -2.0 * cos_w0;
            a2 = 1.0 - alpha;
            break;
        default:
            b0 = 1.0; b1 = 0.0; b2 = 0.0;
            a0 = 1.0; a1 = 0.0; a2 = 0.0;
    }

    // Normalize by a0
    b0 /= a0; b1 /= a0; b2 /= a0;
    a1 /= a0; a2 /= a0;

    Dictionary out;
    Array keys = channels.keys();

    for (int ki = 0; ki < keys.size(); ++ki) {
        String name = keys[ki];
        PackedFloat32Array data = channels[name];
        int sample_count = data.size();
        if (sample_count == 0) continue;

        // Get or create filter state for this channel
        FilterState *fs;
        if (!_state.has(name)) {
            _state[name] = FilterState();
        }
        fs = &_state[name];

        PackedFloat32Array output;
        output.resize(sample_count);
        const float *in = data.ptr();
        float *buf = output.ptrw();

        for (int i = 0; i < sample_count; ++i) {
            double x = (double)in[i];
            double y = b0 * x + b1 * fs->x1 + b2 * fs->x2 - a1 * fs->y1 - a2 * fs->y2;

            fs->x2 = fs->x1;
            fs->x1 = x;
            fs->y2 = fs->y1;
            fs->y1 = y;

            buf[i] = (float)y;
        }

        out[name] = output;
    }

    return out;
}

} // namespace godot
