#include "gn_native_wireframe_sop.h"

#include <godot_cpp/core/class_db.hpp>

namespace godot {

void GNNativeWireframeSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "indices"),
                         &GNNativeWireframeSop::process);
}

PackedVector3Array GNNativeWireframeSop::process(const PackedVector3Array &positions,
                                                  const PackedInt32Array &indices) {
    PackedVector3Array line_verts;
    int vc = positions.size();
    int ic = indices.size();
    if (vc < 3 || ic < 3) return line_verts;

    const Vector3 *pos = positions.ptr();
    const int *idx = indices.ptr();
    int tri_count = ic / 3;

    HashMap<int64_t, bool> edge_set;

    for (int t = 0; t < tri_count; ++t) {
        int i0 = idx[t * 3], i1 = idx[t * 3 + 1], i2 = idx[t * 3 + 2];
        int edges[3][2] = { {i0, i1}, {i1, i2}, {i2, i0} };
        for (int e = 0; e < 3; ++e) {
            int a = MIN(edges[e][0], edges[e][1]);
            int b = MAX(edges[e][0], edges[e][1]);
            int64_t key = (int64_t)a * 100000 + b;
            if (!edge_set.has(key)) {
                edge_set[key] = true;
                line_verts.append(pos[a]);
                line_verts.append(pos[b]);
            }
        }
    }

    return line_verts;
}

} // namespace godot
