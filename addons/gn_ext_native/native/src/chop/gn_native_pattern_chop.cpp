#include "gn_native_pattern_chop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativePatternChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "pattern_type", "length",
                                  "param1", "param2", "seed"),
                         &GNNativePatternChop::process);
}

PackedFloat32Array GNNativePatternChop::process(int pattern_type, int length,
                                                 double param1, double param2,
                                                 int seed) {
    if (length < 1) length = 1;

    PackedFloat32Array result;
    result.resize(length);
    float *buf = result.ptrw();

    for (int i = 0; i < length; ++i) {
        double t = (length > 1) ? (double)i / (double)(length - 1) : 0.0;

        switch (pattern_type) {
            case 0: // Ramp: 0 → 1
                buf[i] = (float)t;
                break;
            case 1: { // Step: number of steps = param1 (default 4)
                int steps = (int)(param1 > 1.0 ? param1 : 4.0);
                buf[i] = (float)(std::floor(t * steps) / (double)(steps - 1 > 0 ? steps - 1 : 1));
                break;
            }
            case 2: { // Pulse: duty cycle = param1 (0..1, default 0.5)
                double duty = CLAMP(param1, 0.0, 1.0);
                double period_inv = param2 > 0.0 ? param2 : 1.0; // number of pulses
                double phase = std::fmod(t * period_inv, 1.0);
                buf[i] = phase < duty ? 1.0f : 0.0f;
                break;
            }
            case 3: { // ZigZag: triangle wave over the range
                double freq = param1 > 0.0 ? param1 : 1.0;
                double phase = std::fmod(t * freq, 1.0);
                buf[i] = (float)(1.0 - 2.0 * std::fabs(phase - 0.5));
                break;
            }
            case 4: { // Random
                // Simple hash-based deterministic random
                uint64_t h = (uint64_t)(seed * 1000003) ^ (uint64_t)(i * 2654435761ULL);
                h ^= (h >> 16);
                h *= 0x45d9f3bULL;
                h ^= (h >> 16);
                buf[i] = (float)((h & 0xFFFFFF) / (double)0xFFFFFF);
                break;
            }
            default:
                buf[i] = 0.0f;
                break;
        }
    }

    return result;
}

} // namespace godot
