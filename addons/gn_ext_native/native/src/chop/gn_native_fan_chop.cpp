#include "gn_native_fan_chop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeFanChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "src_samples", "count", "offset", "op", "prefix"),
                         &GNNativeFanChop::process);
}

Dictionary GNNativeFanChop::process(const PackedFloat32Array &src_samples,
                                     int count, double offset, int op,
                                     const String &prefix) {
    Dictionary out;
    int src_len = src_samples.size();
    if (src_len == 0 || count < 1) return out;

    const float *src = src_samples.ptr();

    for (int c = 0; c < count; ++c) {
        String ch_name = prefix + String::num_int64(c);
        PackedFloat32Array dst;
        dst.resize(src_len);
        float *d = dst.ptrw();
        double spread = offset * (c - (count - 1) * 0.5);

        switch (op) {
            case 0: // Add
                for (int i = 0; i < src_len; ++i)
                    d[i] = src[i] + (float)spread;
                break;
            case 1: // Multiply
                for (int i = 0; i < src_len; ++i)
                    d[i] = src[i] * (float)(1.0 + spread);
                break;
            case 2: { // Phase Shift
                int shift = (int)std::round(spread * src_len);
                for (int i = 0; i < src_len; ++i) {
                    int si = ((i + shift) % src_len + src_len) % src_len;
                    d[i] = src[si];
                }
                break;
            }
            default:
                for (int i = 0; i < src_len; ++i)
                    d[i] = src[i] + (float)spread;
                break;
        }

        out[ch_name] = dst;
    }

    return out;
}

} // namespace godot
