#include "gn_native_slope_chop.h"

#include <godot_cpp/core/class_db.hpp>

namespace godot {

void GNNativeSlopeChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "channels", "method", "scale", "reset"),
                         &GNNativeSlopeChop::process);
    ClassDB::bind_method(D_METHOD("clear_state"), &GNNativeSlopeChop::clear_state);
}

void GNNativeSlopeChop::clear_state() {
    _prev_last.clear();
}

Dictionary GNNativeSlopeChop::process(const Dictionary &channels, int method,
                                       double scale, bool reset) {
    if (reset) _prev_last.clear();

    Dictionary out;
    Array keys = channels.keys();

    for (int ki = 0; ki < keys.size(); ++ki) {
        String name = keys[ki];
        PackedFloat32Array data = channels[name];
        int count = data.size();
        if (count == 0) continue;

        const float *in_ptr = data.ptr();
        PackedFloat32Array result;
        result.resize(count);
        float *out_ptr = result.ptrw();

        double prev = _prev_last.has(name) ? _prev_last[name] : (double)in_ptr[0];

        if (method == 1 && count >= 3) {
            // Central difference
            out_ptr[0] = (float)((in_ptr[1] - prev) * 0.5 * scale);
            for (int i = 1; i < count - 1; ++i) {
                out_ptr[i] = (float)(((double)in_ptr[i + 1] - (double)in_ptr[i - 1]) * 0.5 * scale);
            }
            out_ptr[count - 1] = (float)(((double)in_ptr[count - 1] - (double)in_ptr[count - 2]) * scale);
        } else {
            // Forward difference
            out_ptr[0] = (float)(((double)in_ptr[0] - prev) * scale);
            for (int i = 1; i < count; ++i) {
                out_ptr[i] = (float)(((double)in_ptr[i] - (double)in_ptr[i - 1]) * scale);
            }
        }

        _prev_last[name] = (double)in_ptr[count - 1];
        out[name] = result;
    }

    return out;
}

} // namespace godot
