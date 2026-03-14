#include "gn_native_transform_sop.h"

#include <godot_cpp/core/class_db.hpp>

namespace godot {

void GNNativeTransformSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "verts", "normals", "xform"),
                         &GNNativeTransformSop::process);
}

Dictionary GNNativeTransformSop::process(const PackedVector3Array &verts,
                                          const PackedVector3Array &normals,
                                          const Transform3D &xform) {
    Dictionary result;
    int n = verts.size();

    PackedVector3Array out_verts;
    out_verts.resize(n);
    Vector3 *ov = out_verts.ptrw();
    const Vector3 *vp = verts.ptr();

    for (int i = 0; i < n; ++i) {
        ov[i] = xform.xform(vp[i]);
    }
    result["positions"] = out_verts;

    if ((int)normals.size() == n) {
        Basis basis_inv_t = xform.basis.inverse().transposed();
        PackedVector3Array out_normals;
        out_normals.resize(n);
        Vector3 *on = out_normals.ptrw();
        const Vector3 *np = normals.ptr();
        for (int i = 0; i < n; ++i) {
            on[i] = basis_inv_t.xform(np[i]).normalized();
        }
        result["normals"] = out_normals;
    }

    return result;
}

} // namespace godot
