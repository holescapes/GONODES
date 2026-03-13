#include "gn_native_math_chop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeMathChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process_binary", "channels_a", "channels_b", "operation"),
                         &GNNativeMathChop::process_binary);
    ClassDB::bind_method(D_METHOD("process_unary", "channels_a", "operation", "operand"),
                         &GNNativeMathChop::process_unary);
}

static inline double _apply_op(int op, double a, double b) {
    switch (op) {
        case 0: return a + b;
        case 1: return a - b;
        case 2: return a * b;
        case 3: return b != 0.0 ? a / b : 0.0;
        case 4: return std::fabs(a);
        case 5: return std::sin(a);
        case 6: return std::cos(a);
        case 7: return a >= 0.0 ? std::pow(a, b) : 0.0;
        default: return a;
    }
}

Dictionary GNNativeMathChop::process_binary(const Dictionary &channels_a,
                                             const Dictionary &channels_b,
                                             int operation) {
    Dictionary out;
    Array keys_a = channels_a.keys();
    Array keys_b = channels_b.keys();

    // Single-channel broadcast from B
    PackedFloat32Array b_single;
    if (keys_b.size() == 1) {
        b_single = channels_b[keys_b[0]];
    }

    for (int ki = 0; ki < keys_a.size(); ++ki) {
        String name = keys_a[ki];
        PackedFloat32Array data_a = channels_a[name];
        PackedFloat32Array data_b;

        // Match by name first, then single-channel broadcast, then index
        if (channels_b.has(name)) {
            data_b = channels_b[name];
        } else if (b_single.size() > 0) {
            data_b = b_single;
        } else if (ki < keys_b.size()) {
            data_b = channels_b[keys_b[ki]];
        }

        int count = data_a.size();
        PackedFloat32Array result;
        result.resize(count);
        const float *a_ptr = data_a.ptr();
        float *out_ptr = result.ptrw();

        if (data_b.size() > 0) {
            const float *b_ptr = data_b.ptr();
            int b_count = data_b.size();
            for (int i = 0; i < count; ++i) {
                double bv = (i < b_count) ? (double)b_ptr[i] : (double)b_ptr[b_count - 1];
                out_ptr[i] = (float)_apply_op(operation, (double)a_ptr[i], bv);
            }
        } else {
            for (int i = 0; i < count; ++i) {
                out_ptr[i] = (float)_apply_op(operation, (double)a_ptr[i], 0.0);
            }
        }

        out[name] = result;
    }
    return out;
}

Dictionary GNNativeMathChop::process_unary(const Dictionary &channels_a,
                                            int operation, double operand) {
    Dictionary out;
    Array keys = channels_a.keys();

    for (int ki = 0; ki < keys.size(); ++ki) {
        String name = keys[ki];
        PackedFloat32Array data = channels_a[name];
        int count = data.size();

        PackedFloat32Array result;
        result.resize(count);
        const float *in_ptr = data.ptr();
        float *out_ptr = result.ptrw();

        for (int i = 0; i < count; ++i) {
            out_ptr[i] = (float)_apply_op(operation, (double)in_ptr[i], operand);
        }

        out[name] = result;
    }
    return out;
}

} // namespace godot
