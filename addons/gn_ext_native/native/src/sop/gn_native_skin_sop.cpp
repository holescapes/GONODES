#include "gn_native_skin_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <algorithm>

namespace godot {

void GNNativeSkinSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "cross_sections", "close_u", "close_v"),
                         &GNNativeSkinSop::process);
}

Dictionary GNNativeSkinSop::process(const Array &cross_sections,
                                     bool close_u, bool close_v) {
    // Identical to PolyLoft in surface generation
    Dictionary result;
    int num_sections = cross_sections.size();
    if (num_sections < 2) {
        result["positions"] = PackedVector3Array();
        result["normals"] = PackedVector3Array();
        result["uvs"] = PackedVector2Array();
        result["indices"] = PackedInt32Array();
        return result;
    }

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
    PackedVector3Array out_pos; out_pos.resize(total_verts);
    PackedVector3Array out_nrm; out_nrm.resize(total_verts);
    PackedVector2Array out_uvs; out_uvs.resize(total_verts);
    Vector3 *op = out_pos.ptrw();
    Vector3 *on = out_nrm.ptrw();
    Vector2 *ou = out_uvs.ptrw();

    for (int si = 0; si < num_sections; ++si) {
        PackedVector3Array sec = cross_sections[si];
        const Vector3 *sp = sec.ptr();
        double v_coord = (double)si / (double)(num_sections - 1);
        for (int pi = 0; pi < pts; ++pi) {
            int idx = si * pts + pi;
            op[idx] = sp[pi];
            ou[idx] = Vector2((double)pi / (double)(pts - 1), v_coord);
        }
    }

    // Normals via cross product of tangent vectors
    for (int si = 0; si < num_sections; ++si) {
        for (int pi = 0; pi < pts; ++pi) {
            int idx = si * pts + pi;
            int ns = std::min(si + 1, num_sections - 1);
            int ps_idx = std::max(si - 1, 0);
            int np = close_u ? (pi + 1) % pts : std::min(pi + 1, pts - 1);
            int pp = close_u ? (pi - 1 + pts) % pts : std::max(pi - 1, 0);
            Vector3 du = op[si * pts + np] - op[si * pts + pp];
            Vector3 dv = op[ns * pts + pi] - op[ps_idx * pts + pi];
            Vector3 n = du.cross(dv);
            double len = n.length();
            on[idx] = len > 0.0001 ? n / len : Vector3(0, 1, 0);
        }
    }

    int seg_u = close_u ? pts : pts - 1;
    int seg_v = close_v ? num_sections : num_sections - 1;
    PackedInt32Array out_idx;
    out_idx.resize(seg_u * seg_v * 6);
    int32_t *oi = out_idx.ptrw();
    int w = 0;

    for (int si = 0; si < seg_v; ++si) {
        int next_si = (si + 1) % num_sections;
        for (int pi = 0; pi < seg_u; ++pi) {
            int next_pi = (pi + 1) % pts;
            int i00 = si * pts + pi;
            int i01 = si * pts + next_pi;
            int i10 = next_si * pts + pi;
            int i11 = next_si * pts + next_pi;
            oi[w++] = i00; oi[w++] = i10; oi[w++] = i01;
            oi[w++] = i01; oi[w++] = i10; oi[w++] = i11;
        }
    }

    result["positions"] = out_pos;
    result["normals"] = out_nrm;
    result["uvs"] = out_uvs;
    result["indices"] = out_idx;
    return result;
}

} // namespace godot
