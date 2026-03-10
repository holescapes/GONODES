#include "gn_native_copy.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <cmath>

using namespace godot;

void GNNativeCopy::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "tmpl_positions", "tmpl_normals",
                                  "tmpl_uvs", "tmpl_indices",
                                  "target_positions", "target_normals",
                                  "pscale", "align_to_normal", "base_scale"),
                         &GNNativeCopy::process);
}

static Basis _basis_from_normal(const Vector3 &n) {
    Vector3 up = n;
    Vector3 right;
    if (std::fabs(up.dot(Vector3(0, 1, 0))) > 0.999f) {
        right = Vector3(1, 0, 0);
    } else {
        right = up.cross(Vector3(0, 1, 0)).normalized();
    }
    Vector3 forward = right.cross(up).normalized();
    return Basis(right, up, forward);
}

Dictionary GNNativeCopy::process(const PackedVector3Array &tmpl_positions,
                                  const PackedVector3Array &tmpl_normals,
                                  const PackedVector2Array &tmpl_uvs,
                                  const PackedInt32Array &tmpl_indices,
                                  const PackedVector3Array &target_positions,
                                  const PackedVector3Array &target_normals,
                                  const PackedFloat32Array &pscale,
                                  bool align_to_normal, double base_scale) {
    int tvert = tmpl_positions.size();
    int npoints = target_positions.size();
    bool has_normals = !tmpl_normals.is_empty();
    bool has_uvs = !tmpl_uvs.is_empty();
    bool has_indices = !tmpl_indices.is_empty();

    int64_t total_verts = (int64_t)tvert * npoints;

    PackedVector3Array out_pos;
    out_pos.resize(total_verts);
    PackedVector3Array out_nrm;
    if (has_normals) out_nrm.resize(total_verts);
    PackedVector2Array out_uvs;
    if (has_uvs) out_uvs.resize(total_verts);
    PackedInt32Array out_idx;
    if (has_indices) out_idx.resize((int64_t)tmpl_indices.size() * npoints);

    const Vector3 *tp = tmpl_positions.ptr();
    const Vector3 *tn = has_normals ? tmpl_normals.ptr() : nullptr;
    const Vector2 *tu = has_uvs ? tmpl_uvs.ptr() : nullptr;
    const int32_t *ti = has_indices ? tmpl_indices.ptr() : nullptr;
    const Vector3 *tgt_p = target_positions.ptr();
    const Vector3 *tgt_n = target_normals.ptr();
    const float *ps = pscale.ptr();
    int ps_count = pscale.size();
    int ti_count = has_indices ? tmpl_indices.size() : 0;

    Vector3 *op = out_pos.ptrw();
    Vector3 *on = has_normals ? out_nrm.ptrw() : nullptr;
    Vector2 *ou = has_uvs ? out_uvs.ptrw() : nullptr;
    int32_t *oi = has_indices ? out_idx.ptrw() : nullptr;

    for (int pi = 0; pi < npoints; ++pi) {
        Vector3 pos = tgt_p[pi];
        Vector3 n = (pi < (int)target_normals.size()) ? tgt_n[pi] : Vector3(0, 1, 0);
        float s = (float)base_scale;
        if (pi < ps_count) s *= ps[pi];

        Transform3D xform;
        if (align_to_normal && n.length_squared() > 0.001f) {
            xform.basis = _basis_from_normal(n.normalized());
        }
        xform.basis = xform.basis.scaled(Vector3(s, s, s));
        xform.origin = pos;

        int base_v = pi * tvert;
        for (int vi = 0; vi < tvert; ++vi) {
            op[base_v + vi] = xform.xform(tp[vi]);
            if (on && vi < (int)tmpl_normals.size()) {
                on[base_v + vi] = (xform.basis.xform(tn[vi])).normalized();
            }
            if (ou && vi < (int)tmpl_uvs.size()) {
                ou[base_v + vi] = tu[vi];
            }
        }

        if (oi) {
            int base_i = pi * ti_count;
            for (int ii = 0; ii < ti_count; ++ii) {
                oi[base_i + ii] = ti[ii] + base_v;
            }
        }
    }

    Dictionary result;
    result["positions"] = out_pos;
    result["normals"] = out_nrm;
    result["uvs"] = out_uvs;
    result["indices"] = out_idx;
    return result;
}
