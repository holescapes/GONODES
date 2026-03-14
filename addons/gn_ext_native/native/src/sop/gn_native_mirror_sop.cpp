#include "gn_native_mirror_sop.h"

#include <godot_cpp/core/class_db.hpp>

namespace godot {

void GNNativeMirrorSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "verts", "normals", "indices",
                                  "mirror_axis", "origin", "reverse_winding"),
                         &GNNativeMirrorSop::process);
}

Dictionary GNNativeMirrorSop::process(const PackedVector3Array &verts,
                                       const PackedVector3Array &normals,
                                       const PackedInt32Array &indices,
                                       const Vector3 &mirror_axis,
                                       double origin,
                                       bool reverse_winding) {
    Dictionary result;
    int nv = verts.size();
    bool has_normals = (int)normals.size() == nv;

    const Vector3 *vp = verts.ptr();
    Vector3 axis = mirror_axis.normalized();

    // Mirrored copy
    PackedVector3Array m_verts;
    m_verts.resize(nv);
    Vector3 *mv = m_verts.ptrw();

    PackedVector3Array m_normals;
    if (has_normals) {
        m_normals.resize(nv);
    }
    Vector3 *mn = has_normals ? m_normals.ptrw() : nullptr;

    for (int i = 0; i < nv; ++i) {
        Vector3 p = vp[i];
        float d = p.dot(axis) - (float)origin;
        mv[i] = p - axis * (2.0f * d);
        if (has_normals) {
            Vector3 n = normals.ptr()[i];
            mn[i] = (n - axis * (2.0f * n.dot(axis))).normalized();
        }
    }

    // Combine original + mirrored positions
    PackedVector3Array all_verts;
    all_verts.resize(nv * 2);
    Vector3 *av = all_verts.ptrw();
    for (int i = 0; i < nv; ++i) av[i] = vp[i];
    for (int i = 0; i < nv; ++i) av[nv + i] = mv[i];

    PackedVector3Array all_normals;
    if (has_normals) {
        all_normals.resize(nv * 2);
        Vector3 *an = all_normals.ptrw();
        const Vector3 *np_orig = normals.ptr();
        for (int i = 0; i < nv; ++i) an[i] = np_orig[i];
        for (int i = 0; i < nv; ++i) an[nv + i] = mn[i];
    }

    // Combine indices
    int ni = indices.size();
    PackedInt32Array all_indices;
    all_indices.resize(ni * 2);
    int *ai = all_indices.ptrw();
    const int *ip = indices.ptr();

    for (int i = 0; i < ni; ++i) ai[i] = ip[i];

    if (reverse_winding) {
        for (int t = 0; t < ni / 3; ++t) {
            ai[ni + t * 3] = ip[t * 3] + nv;
            ai[ni + t * 3 + 1] = ip[t * 3 + 2] + nv; // Swapped
            ai[ni + t * 3 + 2] = ip[t * 3 + 1] + nv;
        }
    } else {
        for (int i = 0; i < ni; ++i) ai[ni + i] = ip[i] + nv;
    }

    result["positions"] = all_verts;
    result["normals"] = all_normals;
    result["indices"] = all_indices;
    return result;
}

} // namespace godot
