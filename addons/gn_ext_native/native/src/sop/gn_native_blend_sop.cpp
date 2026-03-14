#include "gn_native_blend_sop.h"

#include <godot_cpp/core/class_db.hpp>

namespace godot {

void GNNativeBlendSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "verts_a", "verts_b",
                                  "normals_a", "normals_b", "uvs_a", "uvs_b",
                                  "blend", "do_normals", "do_uvs"),
                         &GNNativeBlendSop::process);
}

Dictionary GNNativeBlendSop::process(const PackedVector3Array &verts_a,
                                      const PackedVector3Array &verts_b,
                                      const PackedVector3Array &normals_a,
                                      const PackedVector3Array &normals_b,
                                      const PackedVector2Array &uvs_a,
                                      const PackedVector2Array &uvs_b,
                                      double blend, bool do_normals, bool do_uvs) {
    int count = verts_a.size();
    Dictionary result;

    if (count == 0 || verts_b.size() != count) {
        result["positions"] = verts_a;
        result["normals"] = normals_a;
        result["uvs"] = uvs_a;
        return result;
    }

    const Vector3 *a = verts_a.ptr();
    const Vector3 *b = verts_b.ptr();
    float t = (float)CLAMP(blend, 0.0, 1.0);
    float inv_t = 1.0f - t;

    // Blend positions
    PackedVector3Array out_pos;
    out_pos.resize(count);
    Vector3 *op = out_pos.ptrw();
    for (int i = 0; i < count; ++i) {
        op[i] = a[i] * inv_t + b[i] * t;
    }
    result["positions"] = out_pos;

    // Blend normals
    if (do_normals && normals_a.size() == count && normals_b.size() == count) {
        const Vector3 *na = normals_a.ptr();
        const Vector3 *nb = normals_b.ptr();
        PackedVector3Array out_nrm;
        out_nrm.resize(count);
        Vector3 *on = out_nrm.ptrw();
        for (int i = 0; i < count; ++i) {
            on[i] = (na[i] * inv_t + nb[i] * t).normalized();
        }
        result["normals"] = out_nrm;
    } else {
        result["normals"] = normals_a;
    }

    // Blend UVs
    if (do_uvs && uvs_a.size() == count && uvs_b.size() == count) {
        const Vector2 *ua = uvs_a.ptr();
        const Vector2 *ub = uvs_b.ptr();
        PackedVector2Array out_uvs;
        out_uvs.resize(count);
        Vector2 *ou = out_uvs.ptrw();
        for (int i = 0; i < count; ++i) {
            ou[i] = ua[i] * inv_t + ub[i] * t;
        }
        result["uvs"] = out_uvs;
    } else {
        result["uvs"] = uvs_a;
    }

    return result;
}

} // namespace godot
