#include "gn_native_instance_pop.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/transform3d.hpp>

namespace godot {

void GNNativeInstancePop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "pscales",
                                  "src_verts", "src_normals", "src_indices",
                                  "colors_flat", "max_instances",
                                  "use_pscale", "use_color"),
                         &GNNativeInstancePop::process);
}

Dictionary GNNativeInstancePop::process(const PackedVector3Array &positions,
                                         const PackedFloat32Array &pscales,
                                         const PackedVector3Array &src_verts,
                                         const PackedVector3Array &src_normals,
                                         const PackedInt32Array &src_indices,
                                         const PackedFloat32Array &colors_flat,
                                         int max_instances,
                                         bool use_pscale, bool use_color) {
    Dictionary result;
    int count = MIN((int)positions.size(), max_instances);
    int sv = src_verts.size();
    int si = src_indices.size();
    bool has_normals = (int)src_normals.size() == sv;
    bool has_indices = si > 0;

    if (count <= 0 || sv <= 0) {
        result["positions"] = PackedVector3Array();
        result["normals"] = PackedVector3Array();
        result["indices"] = PackedInt32Array();
        result["colors"] = PackedColorArray();
        return result;
    }

    PackedVector3Array all_verts;
    all_verts.resize(sv * count);
    Vector3 *av = all_verts.ptrw();

    PackedVector3Array all_normals;
    if (has_normals) {
        all_normals.resize(sv * count);
    }
    Vector3 *an = has_normals ? all_normals.ptrw() : nullptr;

    PackedInt32Array all_indices;
    if (has_indices) {
        all_indices.resize(si * count);
    }
    int *ai = has_indices ? all_indices.ptrw() : nullptr;

    PackedColorArray all_colors;
    bool emit_color = use_color && (int)colors_flat.size() >= count * 4;
    if (emit_color) {
        all_colors.resize(sv * count);
    }
    Color *ac = emit_color ? all_colors.ptrw() : nullptr;

    const Vector3 *pos = positions.ptr();
    const float *ps = pscales.ptr();
    const Vector3 *svp = src_verts.ptr();
    const Vector3 *snp = has_normals ? src_normals.ptr() : nullptr;
    const int *sip = has_indices ? src_indices.ptr() : nullptr;
    const float *cf = emit_color ? colors_flat.ptr() : nullptr;

    for (int i = 0; i < count; ++i) {
        Transform3D xform;
        xform.origin = pos[i];
        if (use_pscale && i < (int)pscales.size()) {
            float s = ps[i];
            xform.basis.scale(Vector3(s, s, s));
        }

        int base_v = i * sv;
        Basis basis = xform.basis;

        for (int v = 0; v < sv; ++v) {
            av[base_v + v] = xform.xform(svp[v]);
        }

        if (has_normals) {
            for (int v = 0; v < sv; ++v) {
                an[base_v + v] = basis.xform(snp[v]).normalized();
            }
        }

        if (has_indices) {
            int base_i = i * si;
            for (int idx = 0; idx < si; ++idx) {
                ai[base_i + idx] = sip[idx] + base_v;
            }
        }

        if (emit_color) {
            Color c(cf[i * 4], cf[i * 4 + 1], cf[i * 4 + 2], cf[i * 4 + 3]);
            for (int v = 0; v < sv; ++v) {
                ac[base_v + v] = c;
            }
        }
    }

    result["positions"] = all_verts;
    result["normals"] = all_normals;
    result["indices"] = all_indices;
    result["colors"] = all_colors;
    return result;
}

} // namespace godot
