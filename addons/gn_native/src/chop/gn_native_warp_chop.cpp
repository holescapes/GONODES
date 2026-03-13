#include "gn_native_warp_chop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <algorithm>

namespace godot {

void GNNativeWarpChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "channels_a", "warp_curve", "quality"),
                         &GNNativeWarpChop::process);
}

Dictionary GNNativeWarpChop::process(const Dictionary &channels_a,
                                      const PackedFloat32Array &warp_curve,
                                      int quality) {
    Dictionary out;
    int warp_count = warp_curve.size();
    if (warp_count == 0) return channels_a.duplicate();

    const float *warp_ptr = warp_curve.ptr();
    Array keys = channels_a.keys();

    for (int ki = 0; ki < keys.size(); ++ki) {
        String name = keys[ki];
        PackedFloat32Array data = channels_a[name];
        int src_count = data.size();
        if (src_count == 0) continue;

        const float *src = data.ptr();

        // Output length matches warp curve length
        int out_count = warp_count;
        PackedFloat32Array result;
        result.resize(out_count);
        float *dst = result.ptrw();

        for (int i = 0; i < out_count; ++i) {
            // Warp value is normalized 0..1 → maps to src index
            double wv = (double)warp_ptr[i];
            double pos = wv * std::max(src_count - 1.0, 0.0);

            if (quality == 1) {
                // Nearest
                int idx = std::clamp((int)std::round(pos), 0, src_count - 1);
                dst[i] = src[idx];
            } else {
                // Linear
                int lo = std::clamp((int)pos, 0, src_count - 1);
                int hi = std::clamp(lo + 1, 0, src_count - 1);
                double frac = pos - (double)lo;
                dst[i] = (float)(src[lo] * (1.0 - frac) + src[hi] * frac);
            }
        }

        out[name] = result;
    }

    return out;
}

} // namespace godot
