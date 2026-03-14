#include "gn_native_resample_chop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <algorithm>

namespace godot {

void GNNativeResampleChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "channels", "target_samples", "quality"),
                         &GNNativeResampleChop::process);
}

static float _interp_sample(const float *src, int n, double pos, int quality) {
    if (n == 0) return 0.0f;
    if (n == 1) return src[0];

    switch (quality) {
        case 2: { // Nearest
            int idx = std::clamp((int)std::round(pos), 0, n - 1);
            return src[idx];
        }
        case 1: { // Cubic (Catmull-Rom)
            int i1 = std::clamp((int)pos, 0, n - 1);
            double frac = pos - (double)i1;
            int i0 = std::clamp(i1 - 1, 0, n - 1);
            int i2 = std::clamp(i1 + 1, 0, n - 1);
            int i3 = std::clamp(i1 + 2, 0, n - 1);
            double t2 = frac * frac;
            double t3 = t2 * frac;
            return (float)(0.5 * ((2.0 * src[i1]) +
                (-src[i0] + src[i2]) * frac +
                (2.0 * src[i0] - 5.0 * src[i1] + 4.0 * src[i2] - src[i3]) * t2 +
                (-src[i0] + 3.0 * src[i1] - 3.0 * src[i2] + src[i3]) * t3));
        }
        default: { // Linear
            int lo = std::clamp((int)pos, 0, n - 1);
            int hi = std::clamp(lo + 1, 0, n - 1);
            double frac = pos - (double)lo;
            return (float)(src[lo] * (1.0 - frac) + src[hi] * frac);
        }
    }
}

Dictionary GNNativeResampleChop::process(const Dictionary &channels,
                                          int target_samples, int quality) {
    Dictionary out;
    if (target_samples < 1) target_samples = 1;

    Array keys = channels.keys();
    for (int ki = 0; ki < keys.size(); ++ki) {
        String name = keys[ki];
        PackedFloat32Array data = channels[name];
        int src_count = data.size();
        if (src_count == 0) continue;

        PackedFloat32Array result;
        result.resize(target_samples);
        const float *src_ptr = data.ptr();
        float *dst_ptr = result.ptrw();

        for (int i = 0; i < target_samples; ++i) {
            double t = (double)i / std::max(target_samples - 1.0, 1.0) *
                       std::max(src_count - 1.0, 0.0);
            dst_ptr[i] = _interp_sample(src_ptr, src_count, t, quality);
        }

        out[name] = result;
    }
    return out;
}

} // namespace godot
