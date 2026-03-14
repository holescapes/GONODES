#include "gn_native_noise_chop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeNoiseChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "num_channels", "time_accum",
                                  "period", "roughness", "seed"),
                         &GNNativeNoiseChop::process);
}

static double _hash_1d(double n) {
    return std::fmod(std::sin(n * 127.1 + 311.7) * 43758.5453, 1.0);
}

static double _smooth_hash_1d(double x) {
    double i = std::floor(x);
    double f = x - i;
    double u = f * f * (3.0 - 2.0 * f);
    return (_hash_1d(i) * (1.0 - u) + _hash_1d(i + 1.0) * u) * 2.0 - 1.0;
}

static double _sample_noise(double t, double period, double roughness, int seed_offset) {
    double scaled_t = t / (period > 0.001 ? period : 0.001);
    double value = 0.0;
    double amp = 1.0;
    double freq = 1.0;
    double total_amp = 0.0;
    int octaves = 1 + (int)(roughness * 4.0);

    for (int oct = 0; oct < octaves; ++oct) {
        value += amp * _smooth_hash_1d(scaled_t * freq + (double)seed_offset * 17.31);
        total_amp += amp;
        amp *= roughness;
        freq *= 2.0;
    }

    if (total_amp > 0.0) value /= total_amp;
    return value;
}

Dictionary GNNativeNoiseChop::process(int num_channels, double time_accum,
                                       double period, double roughness, int seed) {
    Dictionary out;
    for (int ch = 0; ch < num_channels; ++ch) {
        String ch_name = "chan" + String::num_int64(ch + 1);
        double val = _sample_noise(time_accum, period, roughness, seed + ch);
        PackedFloat32Array arr;
        arr.resize(1);
        arr.set(0, (float)val);
        out[ch_name] = arr;
    }
    return out;
}

} // namespace godot
