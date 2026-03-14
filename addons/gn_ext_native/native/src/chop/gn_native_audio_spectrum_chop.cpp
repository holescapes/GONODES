#include "gn_native_audio_spectrum_chop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <vector>

namespace godot {

void GNNativeAudioSpectrumChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "samples", "window_type", "normalize"),
                         &GNNativeAudioSpectrumChop::process);
}

PackedFloat32Array GNNativeAudioSpectrumChop::process(const PackedFloat32Array &samples,
                                                       int window_type, bool normalize) {
    int N = samples.size();
    if (N == 0) return PackedFloat32Array();

    const float *src = samples.ptr();

    // Apply window function
    std::vector<double> windowed(N);
    for (int i = 0; i < N; ++i) {
        double w = 1.0;
        switch (window_type) {
            case 1: // Hann
                w = 0.5 * (1.0 - std::cos(2.0 * Math_PI * i / (N - 1)));
                break;
            case 2: // Hamming
                w = 0.54 - 0.46 * std::cos(2.0 * Math_PI * i / (N - 1));
                break;
        }
        windowed[i] = (double)src[i] * w;
    }

    // Real DFT: compute N/2+1 magnitude bins
    int out_count = N / 2 + 1;
    PackedFloat32Array result;
    result.resize(out_count);
    float *dst = result.ptrw();

    double inv_N = 1.0 / (double)N;

    for (int k = 0; k < out_count; ++k) {
        double re = 0.0;
        double im = 0.0;
        double angle_step = -2.0 * Math_PI * k / (double)N;

        for (int n = 0; n < N; ++n) {
            double angle = angle_step * n;
            re += windowed[n] * std::cos(angle);
            im += windowed[n] * std::sin(angle);
        }

        double mag = std::sqrt(re * re + im * im);
        if (normalize) mag *= inv_N;
        dst[k] = (float)mag;
    }

    return result;
}

} // namespace godot
