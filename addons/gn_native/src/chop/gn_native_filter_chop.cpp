#include "gn_native_filter_chop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeFilterChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "channels", "filter_type", "cutoff", "reset"),
                         &GNNativeFilterChop::process);
    ClassDB::bind_method(D_METHOD("clear_state"), &GNNativeFilterChop::clear_state);
}

void GNNativeFilterChop::clear_state() {
    _prev.clear();
}

Dictionary GNNativeFilterChop::process(const Dictionary &channels, int filter_type,
                                        double cutoff, bool reset) {
    if (reset) _prev.clear();

    double alpha = CLAMP(cutoff, 0.001, 1.0);
    Dictionary out;
    Array keys = channels.keys();

    for (int ki = 0; ki < keys.size(); ++ki) {
        String name = keys[ki];
        PackedFloat32Array data = channels[name];
        int count = data.size();
        if (count == 0) continue;

        const float *in_ptr = data.ptr();
        double prev_val;
        if (_prev.has(name)) {
            prev_val = _prev[name];
        } else {
            prev_val = (double)in_ptr[0];
        }

        PackedFloat32Array result;
        result.resize(count);
        float *out_ptr = result.ptrw();

        for (int i = 0; i < count; ++i) {
            double raw = (double)in_ptr[i];
            if (filter_type == 0) {
                // Low-pass
                double filtered = prev_val + alpha * (raw - prev_val);
                out_ptr[i] = (float)filtered;
                prev_val = filtered;
            } else {
                // High-pass
                double lp = prev_val + alpha * (raw - prev_val);
                out_ptr[i] = (float)(raw - lp);
                prev_val = lp;
            }
        }

        _prev[name] = prev_val;
        out[name] = result;
    }

    return out;
}

} // namespace godot
