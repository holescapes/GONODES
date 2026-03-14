#include "gn_native_carve_sop.h"

#include <godot_cpp/core/class_db.hpp>

namespace godot {

void GNNativeCarveSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "verts", "normals", "uvs",
                                  "indices", "first_u", "second_u",
                                  "extract", "use_uvs", "use_position", "axis"),
                         &GNNativeCarveSop::process);
}

Dictionary GNNativeCarveSop::process(const PackedVector3Array &verts,
                                      const PackedVector3Array &normals,
                                      const PackedVector2Array &uvs,
                                      const PackedInt32Array &indices,
                                      double first_u, double second_u,
                                      bool extract, bool use_uvs,
                                      bool use_position, int axis) {
    Dictionary result;
    int tri_count = indices.size() / 3;
    if (tri_count == 0) {
        result["positions"] = verts;
        result["normals"] = normals;
        result["uvs"] = uvs;
        return result;
    }

    const Vector3 *vp = verts.ptr();
    const Vector3 *np = (int)normals.size() == (int)verts.size() ? normals.ptr() : nullptr;
    const Vector2 *up = (int)uvs.size() == (int)verts.size() ? uvs.ptr() : nullptr;
    const int *ip = indices.ptr();

    float lo = (float)MIN(first_u, second_u);
    float hi = (float)MAX(first_u, second_u);

    PackedVector3Array out_v, out_n;
    PackedVector2Array out_u;

    for (int t = 0; t < tri_count; ++t) {
        int i0 = ip[t * 3], i1 = ip[t * 3 + 1], i2 = ip[t * 3 + 2];

        float param;
        if (use_position) {
            // Use vertex position along axis
            Vector3 center = (vp[i0] + vp[i1] + vp[i2]) / 3.0f;
            switch (axis) {
                case 0: param = center.x; break;
                case 1: param = center.y; break;
                default: param = center.z; break;
            }
        } else if (use_uvs && up) {
            // Use average U coordinate
            float u0 = i0 < (int)uvs.size() ? up[i0].x : 0.0f;
            float u1 = i1 < (int)uvs.size() ? up[i1].x : 0.0f;
            float u2 = i2 < (int)uvs.size() ? up[i2].x : 0.0f;
            param = (u0 + u1 + u2) / 3.0f;
        } else {
            // Index-based parametric
            param = (float)t / (float)tri_count;
        }

        bool in_range = (param >= lo && param <= hi);
        bool keep = extract ? in_range : !in_range;

        if (!keep) continue;

        out_v.push_back(vp[i0]); out_v.push_back(vp[i1]); out_v.push_back(vp[i2]);
        if (np) {
            out_n.push_back(np[i0]); out_n.push_back(np[i1]); out_n.push_back(np[i2]);
        }
        if (up) {
            out_u.push_back(i0 < (int)uvs.size() ? up[i0] : Vector2());
            out_u.push_back(i1 < (int)uvs.size() ? up[i1] : Vector2());
            out_u.push_back(i2 < (int)uvs.size() ? up[i2] : Vector2());
        }
    }

    result["positions"] = out_v;
    result["normals"] = out_n;
    result["uvs"] = out_u;
    return result;
}

} // namespace godot
