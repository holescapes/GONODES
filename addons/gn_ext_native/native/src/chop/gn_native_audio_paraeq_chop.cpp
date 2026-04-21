#include "gn_native_audio_paraeq_chop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif
namespace godot {
void GNNativeAudioParaEqChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "input", "freqs", "gains", "qs", "num_bands", "sr"),
                         &GNNativeAudioParaEqChop::process);
    ClassDB::bind_method(D_METHOD("reset"), &GNNativeAudioParaEqChop::reset);
}
void GNNativeAudioParaEqChop::reset() {
    memset(_x1, 0, sizeof(_x1)); memset(_x2, 0, sizeof(_x2));
    memset(_y1, 0, sizeof(_y1)); memset(_y2, 0, sizeof(_y2));
}
PackedFloat32Array GNNativeAudioParaEqChop::process(const PackedFloat32Array &input,
        const PackedFloat32Array &freqs, const PackedFloat32Array &gains,
        const PackedFloat32Array &qs, int num_bands, double sr) {
    int n = input.size();
    PackedFloat32Array out;
    out.resize(n);
    if (n == 0) return out;
    memcpy(out.ptrw(), input.ptr(), n * sizeof(float));
    int bands = num_bands < MAX_BANDS ? num_bands : MAX_BANDS;
    int ch = 2; int frames = n / ch;
    for (int b = 0; b < bands; ++b) {
        double freq = (b < freqs.size()) ? (double)freqs[b] : 1000.0;
        double gain = (b < gains.size()) ? (double)gains[b] : 0.0;
        double q = (b < qs.size()) ? (double)qs[b] : 1.0;
        if (q < 0.01) q = 0.01;
        double A = pow(10.0, gain / 40.0);
        double w0 = 2.0 * M_PI * freq / sr;
        double alpha = sin(w0) / (2.0 * q);
        double b0 = 1.0 + alpha * A, b1 = -2.0 * cos(w0), b2 = 1.0 - alpha * A;
        double a0 = 1.0 + alpha / A, a1 = -2.0 * cos(w0), a2 = 1.0 - alpha / A;
        b0 /= a0; b1 /= a0; b2 /= a0; a1 /= a0; a2 /= a0;
        float *op = out.ptrw();
        for (int c = 0; c < ch; ++c) {
            for (int i = 0; i < frames; ++i) {
                double x = (double)op[i * ch + c];
                double y = b0 * x + b1 * _x1[b][c] + b2 * _x2[b][c]
                           - a1 * _y1[b][c] - a2 * _y2[b][c];
                _x2[b][c] = _x1[b][c]; _x1[b][c] = x;
                _y2[b][c] = _y1[b][c]; _y1[b][c] = y;
                op[i * ch + c] = (float)y;
            }
        }
    }
    return out;
}
} // namespace godot
