#include "gn_native_area_chop.h"
#include <godot_cpp/core/class_db.hpp>

namespace godot {

void GNNativeAreaChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "channels", "method", "cumulative", "dt"),
                         &GNNativeAreaChop::process);
}

Dictionary GNNativeAreaChop::process(const Dictionary &channels, int method,
                                      bool cumulative, double dt) {
    Dictionary out;
    Array keys = channels.keys();

    for (int ki = 0; ki < keys.size(); ++ki) {
        String name = keys[ki];
        PackedFloat32Array data = channels[name];
        int count = data.size();
        if (count < 2) {
            PackedFloat32Array r;
            r.push_back(0.0f);
            out[name] = r;
            continue;
        }
        const float *in_ptr = data.ptr();

        if (cumulative) {
            PackedFloat32Array result;
            result.resize(count);
            float *out_ptr = result.ptrw();
            out_ptr[0] = 0.0f;
            for (int i = 1; i < count; ++i) {
                float seg;
                if (method == 2) {
                    seg = in_ptr[i - 1] * (float)dt;
                } else {
                    seg = 0.5f * (in_ptr[i - 1] + in_ptr[i]) * (float)dt;
                }
                out_ptr[i] = out_ptr[i - 1] + seg;
            }
            out[name] = result;
        } else {
            double area = 0.0;
            if (method == 1 && count >= 3 && (count - 1) % 2 == 0) {
                for (int i = 0; i < count - 2; i += 2) {
                    area += (dt / 3.0) * ((double)in_ptr[i] + 4.0 * (double)in_ptr[i + 1] + (double)in_ptr[i + 2]);
                }
            } else if (method == 2) {
                for (int i = 0; i < count - 1; ++i) {
                    area += (double)in_ptr[i] * dt;
                }
            } else {
                for (int i = 1; i < count; ++i) {
                    area += 0.5 * ((double)in_ptr[i - 1] + (double)in_ptr[i]) * dt;
                }
            }
            PackedFloat32Array result;
            result.push_back((float)area);
            out[name] = result;
        }
    }
    return out;
}

} // namespace godot
