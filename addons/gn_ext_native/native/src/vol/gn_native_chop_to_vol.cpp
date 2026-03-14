#include "gn_native_chop_to_vol.h"

#include <godot_cpp/core/class_db.hpp>
#include <cstring>

namespace godot {

void GNNativeChopToVol::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "mode", "channels", "ch_names",
                                  "channel_name", "res_x", "res_y", "res_z"),
                         &GNNativeChopToVol::process);
}

PackedByteArray GNNativeChopToVol::process(int mode,
                                            const Dictionary &channels,
                                            const PackedStringArray &ch_names,
                                            const String &channel_name,
                                            int res_x, int res_y, int res_z) {
    int total = res_x * res_y * res_z;
    PackedByteArray bytes;
    bytes.resize(total * 4);
    uint8_t *bw = bytes.ptrw();
    memset(bw, 0, total * 4);

    // Alias as float array
    float *field = reinterpret_cast<float *>(bw);

    if (mode == 0) {
        // Slice — each channel fills one Z-slice
        int slice_size = res_x * res_y;
        int num_ch = ch_names.size();
        for (int zi = 0; zi < MIN(num_ch, res_z); ++zi) {
            Variant v = channels.get(ch_names[zi], Variant());
            if (v.get_type() != Variant::PACKED_FLOAT32_ARRAY) continue;
            PackedFloat32Array samples = v;
            const float *sp = samples.ptr();
            int scount = MIN((int)samples.size(), slice_size);
            for (int i = 0; i < scount; ++i) {
                field[zi * slice_size + i] = sp[i];
            }
        }
    } else if (mode == 1) {
        // Stack — one channel, fill all slices uniformly
        String target = channel_name.is_empty() ? ch_names[0] : channel_name;
        Variant v = channels.get(target, Variant());
        if (v.get_type() != Variant::PACKED_FLOAT32_ARRAY) return bytes;
        PackedFloat32Array samples = v;
        const float *sp = samples.ptr();
        int slice_size = res_x * res_y;
        int scount = MIN((int)samples.size(), slice_size);
        for (int zi = 0; zi < res_z; ++zi) {
            for (int i = 0; i < scount; ++i) {
                field[zi * slice_size + i] = sp[i];
            }
        }
    } else if (mode == 2) {
        // Map — tx/ty/tz → voxel positions, value → density
        Variant vtx = channels.get("tx", Variant());
        Variant vty = channels.get("ty", Variant());
        Variant vtz = channels.get("tz", Variant());
        String target = channel_name.is_empty() ? String("val") : channel_name;
        Variant vvals = channels.get(target, Variant());

        if (vtx.get_type() != Variant::PACKED_FLOAT32_ARRAY) return bytes;
        PackedFloat32Array tx = vtx, ty = vty, tz = vtz, vals = vvals;
        const float *txp = tx.ptr(), *typ = ty.ptr(), *tzp = tz.ptr();
        const float *vp = vals.ptr();
        int count = MIN(MIN((int)tx.size(), (int)ty.size()),
                        MIN((int)tz.size(), (int)vals.size()));
        for (int i = 0; i < count; ++i) {
            int gx = CLAMP((int)(txp[i] * res_x), 0, res_x - 1);
            int gy = CLAMP((int)(typ[i] * res_y), 0, res_y - 1);
            int gz = CLAMP((int)(tzp[i] * res_z), 0, res_z - 1);
            field[gz * res_y * res_x + gy * res_x + gx] += vp[i];
        }
    }

    return bytes;
}

} // namespace godot
