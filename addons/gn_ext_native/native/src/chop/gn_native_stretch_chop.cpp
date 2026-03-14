#include "gn_native_stretch_chop.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

void GNNativeStretchChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "in_channels", "new_length",
                                  "interpolation"),
                         &GNNativeStretchChop::process);
}

float GNNativeStretchChop::_catmull_rom(float p0, float p1, float p2, float p3, float t) {
    float t2 = t * t, t3 = t2 * t;
    return 0.5f * ((2.0f * p1) +
                   (-p0 + p2) * t +
                   (2.0f * p0 - 5.0f * p1 + 4.0f * p2 - p3) * t2 +
                   (-p0 + 3.0f * p1 - 3.0f * p2 + p3) * t3);
}

Dictionary GNNativeStretchChop::process(const Dictionary &in_channels,
                                         int new_length, int interpolation) {
    Dictionary result;
    if (new_length <= 0) return result;

    Array keys = in_channels.keys();
    for (int ci = 0; ci < keys.size(); ++ci) {
        String name = keys[ci];
        Variant cv = in_channels[name];
        if (cv.get_type() != Variant::PACKED_FLOAT32_ARRAY) continue;
        PackedFloat32Array data = cv;
        int old_len = data.size();
        if (old_len == 0) continue;

        const float *dp = data.ptr();
        PackedFloat32Array out;
        out.resize(new_length);
        float *op = out.ptrw();

        if (old_len == 1) {
            for (int i = 0; i < new_length; ++i) op[i] = dp[0];
            result[name] = out;
            continue;
        }

        for (int i = 0; i < new_length; ++i) {
            float t = new_length > 1 ? (float)i / (float)(new_length - 1) : 0.0f;
            float src_f = t * (float)(old_len - 1);
            int idx = (int)src_f;
            float frac = src_f - (float)idx;

            if (interpolation == 2) {
                // Nearest
                int nearest = (frac >= 0.5f) ? idx + 1 : idx;
                op[i] = dp[CLAMP(nearest, 0, old_len - 1)];
            } else if (interpolation == 1) {
                // Cubic (Catmull-Rom)
                int i0 = CLAMP(idx - 1, 0, old_len - 1);
                int i1 = CLAMP(idx, 0, old_len - 1);
                int i2 = CLAMP(idx + 1, 0, old_len - 1);
                int i3 = CLAMP(idx + 2, 0, old_len - 1);
                op[i] = _catmull_rom(dp[i0], dp[i1], dp[i2], dp[i3], frac);
            } else {
                // Linear
                int i1 = CLAMP(idx, 0, old_len - 1);
                int i2 = CLAMP(idx + 1, 0, old_len - 1);
                op[i] = dp[i1] * (1.0f - frac) + dp[i2] * frac;
            }
        }

        result[name] = out;
    }

    return result;
}

} // namespace godot
