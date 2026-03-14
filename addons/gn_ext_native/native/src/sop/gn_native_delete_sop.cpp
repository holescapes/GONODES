#include "gn_native_delete_sop.h"

#include <godot_cpp/core/class_db.hpp>


namespace godot {

void GNNativeDeleteSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "verts", "normals", "uvs",
                                  "indices", "method", "start", "end",
                                  "bmin", "bmax", "percent", "seed", "invert"),
                         &GNNativeDeleteSop::process);
}

Dictionary GNNativeDeleteSop::process(const PackedVector3Array &verts,
                                       const PackedVector3Array &normals,
                                       const PackedVector2Array &uvs,
                                       const PackedInt32Array &indices,
                                       int method, int start, int end,
                                       const Vector3 &bmin, const Vector3 &bmax,
                                       double percent, int seed, bool invert) {
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

    PackedVector3Array out_v, out_n;
    PackedVector2Array out_u;

    srand(seed);

    for (int t = 0; t < tri_count; ++t) {
        int i0 = ip[t * 3], i1 = ip[t * 3 + 1], i2 = ip[t * 3 + 2];

        bool del = false;
        switch (method) {
            case 0: // Range
                del = (t >= start && t <= end);
                break;
            case 1: { // BBox — delete if centroid inside bounding box
                Vector3 center = (vp[i0] + vp[i1] + vp[i2]) / 3.0f;
                del = (center.x >= bmin.x && center.x <= bmax.x &&
                       center.y >= bmin.y && center.y <= bmax.y &&
                       center.z >= bmin.z && center.z <= bmax.z);
                break;
            }
            case 2: // Random
                del = ((double)rand() / (double)RAND_MAX) < percent;
                break;
        }

        if (invert) del = !del;
        if (del) continue;

        // Keep this triangle
        out_v.push_back(vp[i0]); out_v.push_back(vp[i1]); out_v.push_back(vp[i2]);
        if (np) {
            out_n.push_back(np[i0]); out_n.push_back(np[i1]); out_n.push_back(np[i2]);
        }
        if (up) {
            out_u.push_back(up[i0]); out_u.push_back(up[i1]); out_u.push_back(up[i2]);
        }
    }

    result["positions"] = out_v;
    result["normals"] = out_n;
    result["uvs"] = out_u;
    return result;
}

} // namespace godot
