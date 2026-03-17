#include "gn_native_blend_vol.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeBlendVol::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "vol_a", "vol_b",
                                  "total_elements", "op",
                                  "mix_factor", "scale_a", "scale_b"),
                         &GNNativeBlendVol::process);
}

PackedFloat32Array GNNativeBlendVol::process(const PackedFloat32Array &vol_a,
                                              const PackedFloat32Array &vol_b,
                                              int total_elements, int op,
                                              double mix_factor, double scale_a,
                                              double scale_b) {
    PackedFloat32Array out;
    out.resize(total_elements);
    float *o = out.ptrw();
    const float *a = vol_a.ptr();
    const float *b = vol_b.ptr();
    int sa = vol_a.size();
    int sb = vol_b.size();

    for (int i = 0; i < total_elements; ++i) {
        float va = (i < sa) ? a[i] * (float)scale_a : 0.0f;
        float vb = (i < sb) ? b[i] * (float)scale_b : 0.0f;

        switch (op) {
            case 0: o[i] = va + vb; break;
            case 1: o[i] = va - vb; break;
            case 2: o[i] = va * vb; break;
            case 3: o[i] = (va > vb) ? va : vb; break;
            case 4: o[i] = (va < vb) ? va : vb; break;
            case 5: o[i] = va + (float)mix_factor * (vb - va); break;
            default: o[i] = va + vb; break;
        }
    }

    return out;
}

} // namespace godot
