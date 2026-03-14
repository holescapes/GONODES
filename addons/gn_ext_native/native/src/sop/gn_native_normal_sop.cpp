#include "gn_native_normal_sop.h"

#include <godot_cpp/core/class_db.hpp>


namespace godot {

void GNNativeNormalSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "verts", "normals", "uvs",
                                  "indices", "mode"),
                         &GNNativeNormalSop::process);
}

Dictionary GNNativeNormalSop::process(const PackedVector3Array &verts,
                                       const PackedVector3Array &normals,
                                       const PackedVector2Array &uvs,
                                       const PackedInt32Array &indices,
                                       int mode) {
    Dictionary result;
    int nv = verts.size();
    int ni = indices.size();
    int tri_count = ni / 3;

    if (mode == 1) {
        // Flip normals
        PackedVector3Array out_normals;
        out_normals.resize(nv);
        Vector3 *on = out_normals.ptrw();
        const Vector3 *np = normals.ptr();
        bool has_n = (int)normals.size() == nv;
        for (int i = 0; i < nv; ++i) {
            on[i] = has_n ? -np[i] : Vector3(0, -1, 0);
        }
        result["positions"] = verts;
        result["normals"] = out_normals;
        result["uvs"] = uvs;
        return result;

    } else if (mode == 2) {
        // Flat normals — unshare vertices per face
        if (tri_count == 0) {
            result["positions"] = verts;
            result["normals"] = normals;
            result["uvs"] = uvs;
            return result;
        }

        const Vector3 *vp = verts.ptr();
        const Vector2 *up = (int)uvs.size() == nv ? uvs.ptr() : nullptr;
        const int *ip = indices.ptr();

        PackedVector3Array out_verts;
        PackedVector3Array out_normals;
        PackedVector2Array out_uvs;
        int total = tri_count * 3;
        out_verts.resize(total);
        out_normals.resize(total);
        if (up) out_uvs.resize(total);

        Vector3 *ov = out_verts.ptrw();
        Vector3 *on = out_normals.ptrw();
        Vector2 *ou = up ? out_uvs.ptrw() : nullptr;

        for (int t = 0; t < tri_count; ++t) {
            int i0 = ip[t * 3], i1 = ip[t * 3 + 1], i2 = ip[t * 3 + 2];
            Vector3 v0 = vp[i0], v1 = vp[i1], v2 = vp[i2];
            Vector3 fn = (v1 - v0).cross(v2 - v0).normalized();

            int base = t * 3;
            ov[base] = v0; ov[base + 1] = v1; ov[base + 2] = v2;
            on[base] = fn; on[base + 1] = fn; on[base + 2] = fn;
            if (ou) {
                ou[base] = i0 < (int)uvs.size() ? up[i0] : Vector2();
                ou[base + 1] = i1 < (int)uvs.size() ? up[i1] : Vector2();
                ou[base + 2] = i2 < (int)uvs.size() ? up[i2] : Vector2();
            }
        }

        result["positions"] = out_verts;
        result["normals"] = out_normals;
        result["uvs"] = out_uvs;
        return result;

    } else {
        // Smooth normals (mode 0) — accumulate face normals per vertex
        const Vector3 *vp = verts.ptr();
        const int *ip = indices.ptr();

        PackedVector3Array out_normals;
        out_normals.resize(nv);
        Vector3 *on = out_normals.ptrw();
        for (int i = 0; i < nv; ++i) on[i] = Vector3();

        for (int t = 0; t < tri_count; ++t) {
            int i0 = ip[t * 3], i1 = ip[t * 3 + 1], i2 = ip[t * 3 + 2];
            Vector3 fn = (vp[i1] - vp[i0]).cross(vp[i2] - vp[i0]);
            on[i0] += fn; on[i1] += fn; on[i2] += fn;
        }

        for (int i = 0; i < nv; ++i) {
            float len = on[i].length();
            on[i] = len > 1e-7f ? on[i] / len : Vector3(0, 1, 0);
        }

        result["positions"] = verts;
        result["normals"] = out_normals;
        result["uvs"] = uvs;
        return result;
    }
}

} // namespace godot
