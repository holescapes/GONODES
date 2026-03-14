#include "gn_native_trail_chop.h"

#include <godot_cpp/core/class_db.hpp>

namespace godot {

void GNNativeTrailChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "channels", "trail_length"),
                         &GNNativeTrailChop::process);
    ClassDB::bind_method(D_METHOD("reset"), &GNNativeTrailChop::reset);
}

void GNNativeTrailChop::reset() {
    _buffers.clear();
    _write_pos.clear();
    _current_length = 0;
}

Dictionary GNNativeTrailChop::process(const Dictionary &channels, int trail_length) {
    if (trail_length < 2) trail_length = 2;

    // Resize buffers if trail length changed
    if (_current_length != trail_length) {
        _buffers.clear();
        _write_pos.clear();
        _current_length = trail_length;
    }

    Array keys = channels.keys();
    Dictionary out;

    for (int ki = 0; ki < keys.size(); ++ki) {
        String name = keys[ki];
        PackedFloat32Array input = channels[name];
        float new_val = input.size() > 0 ? input[input.size() - 1] : 0.0f;

        // Initialize buffer if needed
        if (!_buffers.has(name)) {
            PackedFloat32Array buf;
            buf.resize(trail_length);
            buf.fill(new_val);
            _buffers[name] = buf;
            _write_pos[name] = 0;
        }

        PackedFloat32Array &buf = _buffers[name];
        int &wp = _write_pos[name];

        // Write new value at write position
        buf.set(wp, new_val);
        wp = (wp + 1) % trail_length;

        // Build output: read from oldest to newest
        PackedFloat32Array result;
        result.resize(trail_length);
        float *dst = result.ptrw();
        const float *src = buf.ptr();
        for (int i = 0; i < trail_length; ++i) {
            dst[i] = src[(wp + i) % trail_length];
        }

        out[name] = result;
    }

    return out;
}

} // namespace godot
