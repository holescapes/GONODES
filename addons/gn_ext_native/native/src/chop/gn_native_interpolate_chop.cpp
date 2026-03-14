#include "gn_native_interpolate_chop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <algorithm>

namespace godot {

void GNNativeInterpolateChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "channels_a", "channels_b", "blend", "method"),
                         &GNNativeInterpolateChop::process);
}

static double _ease(double t, int method) {
    t = CLAMP(t, 0.0, 1.0);
    switch (method) {
        case 1: return t * t;                       // Ease In
        case 2: return 1.0 - (1.0 - t) * (1.0 - t); // Ease Out
        case 3: return t * t * (3.0 - 2.0 * t);     // Smooth Step
        default: return t;                            // Linear
    }
}

Dictionary GNNativeInterpolateChop::process(const Dictionary &channels_a,
                                             const Dictionary &channels_b,
                                             double blend, int method) {
    double t = _ease(blend, method);
    Dictionary out;
    Array keys_a = channels_a.keys();

    for (int ki = 0; ki < keys_a.size(); ++ki) {
        String name = keys_a[ki];
        PackedFloat32Array data_a = channels_a[name];
        int count_a = data_a.size();

        PackedFloat32Array data_b;
        if (channels_b.has(name)) {
            data_b = channels_b[name];
        }

        int count = count_a;
        PackedFloat32Array result;
        result.resize(count);
        const float *a_ptr = data_a.ptr();
        float *out_ptr = result.ptrw();

        if (data_b.size() > 0) {
            const float *b_ptr = data_b.ptr();
            int count_b = data_b.size();
            for (int i = 0; i < count; ++i) {
                double bv = (i < count_b) ? (double)b_ptr[i] : (double)b_ptr[count_b - 1];
                out_ptr[i] = (float)(a_ptr[i] * (1.0 - t) + bv * t);
            }
        } else {
            for (int i = 0; i < count; ++i) {
                out_ptr[i] = (float)(a_ptr[i] * (1.0 - t));
            }
        }

        out[name] = result;
    }

    return out;
}

} // namespace godot
