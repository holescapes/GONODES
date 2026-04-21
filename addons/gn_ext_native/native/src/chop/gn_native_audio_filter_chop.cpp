#include "gn_native_audio_filter_chop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif
namespace godot {
void GNNativeAudioFilterChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "input", "type", "cutoff", "q", "gain_db", "sr"),
                         &GNNativeAudioFilterChop::process);
    ClassDB::bind_method(D_METHOD("reset"), &GNNativeAudioFilterChop::reset);
}
void GNNativeAudioFilterChop::reset() {
    for (int c = 0; c < 2; ++c) { _x1[c]=_x2[c]=_y1[c]=_y2[c]=0.0; }
}
PackedFloat32Array GNNativeAudioFilterChop::process(const PackedFloat32Array &input,
        int type, double cutoff, double q, double gain_db, double sr) {
    int n = input.size();
    PackedFloat32Array out;
    out.resize(n);
    if (n == 0) return out;
    // Biquad coefficients
    double w0 = 2.0 * M_PI * cutoff / sr;
    double alpha = sin(w0) / (2.0 * q);
    double a0, a1, a2, b0, b1, b2;
    switch (type) {
        case 0: // Low pass
            b0 = (1.0 - cos(w0)) / 2.0;
            b1 = 1.0 - cos(w0);
            b2 = b0;
            a0 = 1.0 + alpha; a1 = -2.0 * cos(w0); a2 = 1.0 - alpha;
            break;
        case 1: // High pass
            b0 = (1.0 + cos(w0)) / 2.0;
            b1 = -(1.0 + cos(w0));
            b2 = b0;
            a0 = 1.0 + alpha; a1 = -2.0 * cos(w0); a2 = 1.0 - alpha;
            break;
        case 2: // Band pass
            b0 = alpha;
            b1 = 0.0;
            b2 = -alpha;
            a0 = 1.0 + alpha; a1 = -2.0 * cos(w0); a2 = 1.0 - alpha;
            break;
        default: // Peaking EQ
            { double A = pow(10.0, gain_db / 40.0);
            b0 = 1.0 + alpha * A; b1 = -2.0 * cos(w0); b2 = 1.0 - alpha * A;
            a0 = 1.0 + alpha / A; a1 = -2.0 * cos(w0); a2 = 1.0 - alpha / A; }
    }
    b0 /= a0; b1 /= a0; b2 /= a0; a1 /= a0; a2 /= a0;
    const float *ip = input.ptr();
    float *op = out.ptrw();
    int ch = n > 1 ? 2 : 1; // stereo if even count
    int frames = n / ch;
    for (int c = 0; c < ch; ++c) {
        for (int i = 0; i < frames; ++i) {
            double x = (double)ip[i * ch + c];
            double y = b0 * x + b1 * _x1[c] + b2 * _x2[c] - a1 * _y1[c] - a2 * _y2[c];
            _x2[c] = _x1[c]; _x1[c] = x;
            _y2[c] = _y1[c]; _y1[c] = y;
            op[i * ch + c] = (float)y;
        }
    }
    return out;
}
} // namespace godot
