#include "gn_native_polyloft_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <algorithm>

namespace godot {

void GNNativePolyLoftSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "cross_sections", "close_profiles"),
                         &GNNativePolyLoftSop::process);
}

Dictionary GNNativePolyLoftSop::process(const Array &cross_sections,
                                         bool close_profiles) {
    Dictionary result;
    int num_sections = cross_sections.size();

    if (num_sections < 2) {
        result["positions"] = PackedVector3Array();
        result["normals"] = PackedVector3Array();
        result["uvs"] = PackedVector2Array();
        result["indices"] = PackedInt32Array();
        return result;
    }

    // Determine minimum point count across sections
    int min_pts = INT32_MAX;
    for (int s = 0; s < num_sections; ++s) {
        PackedVector3Array sec = cross_sections[s];
        min_pts = std::min(min_pts, (int)sec.size());
    }
    if (min_pts < 2) {
        result["positions"] = PackedVector3Array();
        result["normals"] = PackedVector3Array();
        result["uvs"] = PackedVector2Array();
        result["indices"] = PackedInt32Array();
        return result;
    }

    int pts = min_pts;
    int total_verts = pts * num_sections;
    PackedVector3Array out_pos;
    out_pos.resize(total_verts);
    PackedVector3Array out_nrm;
    out_nrm.resize(total_verts);
    PackedVector2Array out_uvs;
    out_uvs.resize(total_verts);
    Vector3 *op = out_pos.ptrw();
    Vector3 *on = out_nrm.ptrw();
    Vector2 *ou = out_uvs.ptrw();

    // Fill vertices
    for (int si = 0; si < num_sections; ++si) {
        PackedVector3Array sec = cross_sections[si];
        const Vector3 *sp = sec.ptr();
        double v_coord = (double)si / (double)(num_sections - 1);
        for (int pi = 0; pi < pts; ++pi) {
            int idx = si * pts + pi;
            op[idx] = sp[pi];
            double u_coord = (double)pi / (double)(pts - 1);
            ou[idx] = Vector2(u_coord, v_coord);
        }
    }

    // Compute normals via cross products
    for (int si = 0; si < num_sections; ++si) {
        for (int pi = 0; pi < pts; ++pi) {
            int idx = si * pts + pi;
            int next_s = std::min(si + 1, num_sections - 1);
            int prev_s = std::max(si - 1, 0);
            int next_p = std::min(pi + 1, pts - 1);
            int prev_p = std::max(pi - 1, 0);
            Vector3 du = op[si * pts + next_p] - op[si * pts + prev_p];
            Vector3 dv = op[next_s * pts + pi] - op[prev_s * pts + pi];
            Vector3 n = du.cross(dv);
            double len = n.length();
            on[idx] = len > 0.0001 ? n / len : Vector3(0, 1, 0);
        }
    }

    // Build indices
    int seg_p = close_profiles ? pts : pts - 1;
    int seg_s = num_sections - 1;
    PackedInt32Array out_idx;
    out_idx.resize(seg_p * seg_s * 6);
    int32_t *oi = out_idx.ptrw();
    int write = 0;

    for (int si = 0; si < seg_s; ++si) {
        for (int pi = 0; pi < seg_p; ++pi) {
            int np = (pi + 1) % pts;
            int i00 = si * pts + pi;
            int i01 = si * pts + np;
            int i10 = (si + 1) * pts + pi;
            int i11 = (si + 1) * pts + np;
            oi[write++] = i00; oi[write++] = i10; oi[write++] = i01;
            oi[write++] = i01; oi[write++] = i10; oi[write++] = i11;
        }
    }

    result["positions"] = out_pos;
    result["normals"] = out_nrm;
    result["uvs"] = out_uvs;
    result["indices"] = out_idx;
    return result;
}

} // namespace godot
