#include "gn_native_blend_chop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cstring>

using namespace godot;

void GNNativeBlendChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "inputs", "weights"), &GNNativeBlendChop::process);
}

PackedFloat32Array GNNativeBlendChop::process(const TypedArray<PackedFloat32Array> &p_inputs,
                                                const PackedFloat32Array &p_weights) const {
    PackedFloat32Array out;
    int n_inputs = p_inputs.size();
    if (n_inputs == 0) return out;

    // Find max size across all inputs
    int max_size = 0;
    for (int i = 0; i < n_inputs; i++) {
        PackedFloat32Array arr = p_inputs[i];
        if (arr.size() > max_size) max_size = arr.size();
    }
    if (max_size == 0) return out;

    out.resize(max_size);
    float *dst = out.ptrw();
    memset(dst, 0, max_size * sizeof(float));

    double weight_sum = 0.0;

    for (int i = 0; i < n_inputs; i++) {
        double w = (i < p_weights.size()) ? p_weights[i] : 0.0;
        weight_sum += w;
        if (w == 0.0) continue;

        PackedFloat32Array arr = p_inputs[i];
        const float *src = arr.ptr();
        int sz = arr.size();

        for (int j = 0; j < max_size; j++) {
            // Clamp to last sample if input is shorter
            int idx = (j < sz) ? j : (sz - 1);
            if (idx >= 0) {
                dst[j] += (float)(src[idx] * w);
            }
        }
    }

    // Normalize by weight sum if non-zero
    if (weight_sum > 1e-8 && weight_sum != 1.0) {
        double inv = 1.0 / weight_sum;
        for (int j = 0; j < max_size; j++) {
            dst[j] = (float)(dst[j] * inv);
        }
    }

    return out;
}
