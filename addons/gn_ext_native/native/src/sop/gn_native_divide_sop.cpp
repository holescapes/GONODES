#include "gn_native_divide_sop.h"

#include <godot_cpp/core/class_db.hpp>

namespace godot {

void GNNativeDivideSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("remove_degenerate", "verts", "indices"),
                         &GNNativeDivideSop::remove_degenerate);
}

PackedInt32Array GNNativeDivideSop::remove_degenerate(const PackedVector3Array &verts,
                                                       const PackedInt32Array &indices) {
    int tri_count = indices.size() / 3;
    if (tri_count == 0) return indices;

    const Vector3 *vp = verts.ptr();
    const int *ip = indices.ptr();
    int nv = verts.size();

    PackedInt32Array out;
    out.resize(indices.size());
    int *op = out.ptrw();
    int oi = 0;

    for (int t = 0; t < tri_count; ++t) {
        int i0 = ip[t * 3], i1 = ip[t * 3 + 1], i2 = ip[t * 3 + 2];

        // Skip out-of-range
        if (i0 < 0 || i0 >= nv || i1 < 0 || i1 >= nv || i2 < 0 || i2 >= nv) continue;

        // Skip degenerate (zero-area) triangles
        Vector3 v0 = vp[i0], v1 = vp[i1], v2 = vp[i2];
        Vector3 cross = (v1 - v0).cross(v2 - v0);
        if (cross.length_squared() < 1e-12f) continue;

        op[oi++] = i0;
        op[oi++] = i1;
        op[oi++] = i2;
    }

    out.resize(oi);
    return out;
}

} // namespace godot
