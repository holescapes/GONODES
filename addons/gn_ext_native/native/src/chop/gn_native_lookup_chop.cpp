#include "gn_native_lookup_chop.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>


namespace godot {

void GNNativeLookupChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "table_channels", "index_channels",
                                  "index_ch_names", "interpolation", "extend_mode"),
                         &GNNativeLookupChop::process);
}

static float extend_index(float idx, int len, int mode) {
    if (len <= 1) return 0.0f;
    float max_f = (float)(len - 1);
    switch (mode) {
        case 0: // Clamp
            return CLAMP(idx, 0.0f, max_f);
        case 1: { // Cycle
            float m = fmodf(idx, (float)len);
            if (m < 0.0f) m += (float)len;
            return m;
        }
        case 2: { // Mirror
            float period = max_f * 2.0f;
            float m = fmodf(fabsf(idx), period);
            return m <= max_f ? m : period - m;
        }
        default:
            return CLAMP(idx, 0.0f, max_f);
    }
}

Dictionary GNNativeLookupChop::process(const Dictionary &table_channels,
                                        const Dictionary &index_channels,
                                        const PackedStringArray &index_ch_names,
                                        int interpolation, int extend_mode) {
    Dictionary result;

    // Get first table channel for lookup
    Array table_keys = table_channels.keys();
    if (table_keys.size() == 0) return result;

    String table_name = table_keys[0];
    Variant tv = table_channels[table_name];
    if (tv.get_type() != Variant::PACKED_FLOAT32_ARRAY) return result;
    PackedFloat32Array table = tv;
    int tlen = table.size();
    if (tlen == 0) return result;
    const float *tp = table.ptr();

    for (int ci = 0; ci < (int)index_ch_names.size(); ++ci) {
        String name = index_ch_names[ci];
        Variant iv = index_channels.get(name, Variant());
        if (iv.get_type() != Variant::PACKED_FLOAT32_ARRAY) continue;
        PackedFloat32Array idx_data = iv;
        int count = idx_data.size();
        if (count == 0) continue;

        const float *ip = idx_data.ptr();
        PackedFloat32Array out;
        out.resize(count);
        float *op = out.ptrw();

        for (int i = 0; i < count; ++i) {
            // Map index value (0..1) to table range
            float raw_idx = ip[i] * (float)(tlen - 1);
            float ext_idx = extend_index(raw_idx, tlen, extend_mode);

            if (interpolation == 1) {
                // Nearest
                int ni = (int)(ext_idx + 0.5f);
                op[i] = tp[CLAMP(ni, 0, tlen - 1)];
            } else {
                // Linear
                int lo = CLAMP((int)ext_idx, 0, tlen - 1);
                int hi = CLAMP(lo + 1, 0, tlen - 1);
                float frac = ext_idx - (float)lo;
                op[i] = tp[lo] * (1.0f - frac) + tp[hi] * frac;
            }
        }

        result[name] = out;
    }

    return result;
}

} // namespace godot
