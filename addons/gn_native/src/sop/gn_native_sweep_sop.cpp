#include "gn_native_sweep_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeSweepSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "profile_verts", "backbone_verts",
                                  "scale", "close_profile", "close_backbone"),
                         &GNNativeSweepSop::process);
}

static Vector3 _safe_normalize(const Vector3 &v) {
    double l = v.length();
    return l > 0.0001 ? v / l : Vector3(0, 1, 0);
}

Dictionary GNNativeSweepSop::process(const PackedVector3Array &profile_verts,
                                      const PackedVector3Array &backbone_verts,
                                      double scale, bool close_profile,
                                      bool close_backbone) {
    int prof_count = profile_verts.size();
    int bone_count = backbone_verts.size();
    Dictionary result;

    if (prof_count < 2 || bone_count < 2) {
        result["positions"] = PackedVector3Array();
        result["normals"] = PackedVector3Array();
        result["uvs"] = PackedVector2Array();
        result["indices"] = PackedInt32Array();
        return result;
    }

    const Vector3 *prof = profile_verts.ptr();
    const Vector3 *bone = backbone_verts.ptr();

    int total_verts = prof_count * bone_count;
    PackedVector3Array out_pos;
    out_pos.resize(total_verts);
    PackedVector3Array out_nrm;
    out_nrm.resize(total_verts);
    PackedVector2Array out_uvs;
    out_uvs.resize(total_verts);
    Vector3 *op = out_pos.ptrw();
    Vector3 *on = out_nrm.ptrw();
    Vector2 *ou = out_uvs.ptrw();

    // Build frames along backbone (minimal rotation frame)
    for (int bi = 0; bi < bone_count; ++bi) {
        // Tangent
        Vector3 tangent;
        if (bi == 0) tangent = _safe_normalize(bone[1] - bone[0]);
        else if (bi == bone_count - 1) tangent = _safe_normalize(bone[bi] - bone[bi - 1]);
        else tangent = _safe_normalize(bone[bi + 1] - bone[bi - 1]);

        // Build orthonormal basis
        Vector3 up = Vector3(0, 1, 0);
        if (std::fabs(tangent.dot(up)) > 0.999) up = Vector3(1, 0, 0);
        Vector3 right = tangent.cross(up).normalized();
        Vector3 normal = right.cross(tangent).normalized();

        double v_coord = (double)bi / (double)(bone_count - 1);

        for (int pi = 0; pi < prof_count; ++pi) {
            Vector3 p = prof[pi];
            Vector3 world_pos = bone[bi] + (right * p.x + normal * p.y) * scale;
            int idx = bi * prof_count + pi;
            op[idx] = world_pos;
            on[idx] = _safe_normalize(right * p.x + normal * p.y);
            double u_coord = (double)pi / (double)(prof_count - 1);
            ou[idx] = Vector2(u_coord, v_coord);
        }
    }

    // Build indices (quads as triangles)
    int seg_prof = close_profile ? prof_count : prof_count - 1;
    int seg_bone = close_backbone ? bone_count : bone_count - 1;
    PackedInt32Array out_idx;
    out_idx.resize(seg_prof * seg_bone * 6);
    int32_t *oi = out_idx.ptrw();
    int write = 0;

    for (int bi = 0; bi < seg_bone; ++bi) {
        int next_bi = (bi + 1) % bone_count;
        for (int pi = 0; pi < seg_prof; ++pi) {
            int next_pi = (pi + 1) % prof_count;
            int i00 = bi * prof_count + pi;
            int i01 = bi * prof_count + next_pi;
            int i10 = next_bi * prof_count + pi;
            int i11 = next_bi * prof_count + next_pi;
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
