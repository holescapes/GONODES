#include "gn_native_ramp_chop.h"
#include <godot_cpp/core/class_db.hpp>

namespace godot {

void GNNativeRampChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("evaluate_ramp", "key_positions", "key_values",
                                  "key_left_tangents", "key_right_tangents", "sample_count"),
                         &GNNativeRampChop::evaluate_ramp);
}

static float hermite_eval(float local_t, float v0, float v1, float m0, float m1) {
    float t2 = local_t * local_t;
    float t3 = t2 * local_t;
    return (2.0f * t3 - 3.0f * t2 + 1.0f) * v0
         + (t3 - 2.0f * t2 + local_t) * m0
         + (-2.0f * t3 + 3.0f * t2) * v1
         + (t3 - t2) * m1;
}

PackedFloat32Array GNNativeRampChop::evaluate_ramp(const PackedFloat32Array &key_positions,
                                                     const PackedFloat32Array &key_values,
                                                     const PackedFloat32Array &key_left_tangents,
                                                     const PackedFloat32Array &key_right_tangents,
                                                     int sample_count) {
    PackedFloat32Array result;
    int key_count = key_positions.size();
    if (sample_count < 1) sample_count = 1;
    result.resize(sample_count);
    float *out = result.ptrw();

    if (key_count == 0) {
        for (int i = 0; i < sample_count; ++i) out[i] = 0.0f;
        return result;
    }

    const float *kp = key_positions.ptr();
    const float *kv = key_values.ptr();
    const float *klt = key_left_tangents.ptr();
    const float *krt = key_right_tangents.ptr();

    if (key_count == 1) {
        float val = kv[0];
        for (int i = 0; i < sample_count; ++i) out[i] = val;
        return result;
    }

    int last_idx = key_count - 1;

    for (int s = 0; s < sample_count; ++s) {
        float t;
        if (sample_count == 1) {
            t = 1.0f; // Single-value: evaluate at end of curve
        } else {
            t = (float)s / (float)(sample_count - 1);
        }

        // Clamp to [0, 1]
        if (t < 0.0f) t = 0.0f;
        if (t > 1.0f) t = 1.0f;

        // Before first key
        if (t <= kp[0]) {
            out[s] = kv[0];
            continue;
        }
        // After last key
        if (t >= kp[last_idx]) {
            out[s] = kv[last_idx];
            continue;
        }

        // Find segment via linear scan (keys are sorted, typically few)
        for (int k = 0; k < last_idx; ++k) {
            float p0 = kp[k];
            float p1 = kp[k + 1];
            if (t >= p0 && t <= p1) {
                float span = p1 - p0;
                if (span < 1e-8f) {
                    out[s] = kv[k];
                } else {
                    float local_t = (t - p0) / span;
                    float m0 = krt[k] * span;
                    float m1 = klt[k + 1] * span;
                    out[s] = hermite_eval(local_t, kv[k], kv[k + 1], m0, m1);
                }
                break;
            }
        }
    }

    return result;
}

} // namespace godot
