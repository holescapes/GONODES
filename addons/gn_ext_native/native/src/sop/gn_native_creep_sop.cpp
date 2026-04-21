#include "gn_native_creep_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <cmath>
#include <cfloat>
namespace godot {
void GNNativeCreepSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "source_pts", "target_verts", "target_indices",
                                  "target_normals", "direction", "distance", "seed"),
                         &GNNativeCreepSop::process);
}
static Vector3 closest_point_on_triangle(const Vector3 &p, const Vector3 &a,
                                          const Vector3 &b, const Vector3 &c) {
    Vector3 ab = b - a, ac = c - a, ap = p - a;
    double d1 = ab.dot(ap), d2 = ac.dot(ap);
    if (d1 <= 0 && d2 <= 0) return a;
    Vector3 bp = p - b;
    double d3 = ab.dot(bp), d4 = ac.dot(bp);
    if (d3 >= 0 && d4 <= d3) return b;
    double vc = d1 * d4 - d3 * d2;
    if (vc <= 0 && d1 >= 0 && d3 <= 0) {
        double v = d1 / (d1 - d3);
        return a + ab * v;
    }
    Vector3 cp = p - c;
    double d5 = ab.dot(cp), d6 = ac.dot(cp);
    if (d6 >= 0 && d5 <= d6) return c;
    double vb = d5 * d2 - d1 * d6;
    if (vb <= 0 && d2 >= 0 && d6 <= 0) {
        double w = d2 / (d2 - d6);
        return a + ac * w;
    }
    double va = d3 * d6 - d5 * d4;
    if (va <= 0 && (d4 - d3) >= 0 && (d5 - d6) >= 0) {
        double w = (d4 - d3) / ((d4 - d3) + (d5 - d6));
        return b + (c - b) * w;
    }
    double denom = 1.0 / (va + vb + vc);
    double v = vb * denom, w = vc * denom;
    return a + ab * v + ac * w;
}

PackedVector3Array GNNativeCreepSop::process(const PackedVector3Array &source_pts,
        const PackedVector3Array &target_verts, const PackedInt32Array &target_indices,
        const PackedVector3Array &target_normals, int direction, double distance, int seed) {
    int src_count = source_pts.size();
    int tri_count = target_indices.size() / 3;
    int tgt_vert_count = target_verts.size();
    PackedVector3Array result;
    result.resize(src_count);
    if (tri_count == 0 || tgt_vert_count == 0) {
        for (int i = 0; i < src_count; ++i) result.set(i, source_pts[i]);
        return result;
    }
    const Vector3 *src = source_pts.ptr();
    const Vector3 *tv = target_verts.ptr();
    const int *ti = target_indices.ptr();
    const Vector3 *tn = target_normals.ptr();
    int tn_count = target_normals.size();
    uint32_t rng = (uint32_t)seed;
    for (int i = 0; i < src_count; ++i) {
        Vector3 p = src[i];
        double best_dist = DBL_MAX;
        Vector3 closest_pt = p;
        int best_tri = -1;
        // Find nearest triangle
        for (int t = 0; t < tri_count; ++t) {
            int i0 = ti[t*3], i1 = ti[t*3+1], i2 = ti[t*3+2];
            if (i0 >= tgt_vert_count || i1 >= tgt_vert_count || i2 >= tgt_vert_count) continue;
            Vector3 cp = closest_point_on_triangle(p, tv[i0], tv[i1], tv[i2]);
            double d = (cp - p).length_squared();
            if (d < best_dist) {
                best_dist = d;
                closest_pt = cp;
                best_tri = t;
            }
        }
        // Get displacement direction
        Vector3 disp_dir;
        if (best_tri >= 0) {
            int i0 = ti[best_tri*3], i1 = ti[best_tri*3+1], i2 = ti[best_tri*3+2];
            Vector3 face_normal = (tv[i1] - tv[i0]).cross(tv[i2] - tv[i0]).normalized();
            switch (direction) {
                case 0: // Normal
                    if (i0 < tn_count) disp_dir = tn[i0];
                    else disp_dir = face_normal;
                    break;
                case 1: // Tangent
                    disp_dir = (tv[i1] - tv[i0]).normalized();
                    break;
                case 2: // Random
                    rng = rng * 1103515245u + 12345u;
                    disp_dir = Vector3(
                        (float)((int)(rng >> 16 & 0x7FFF) - 16383) / 16383.0f,
                        (float)((int)((rng = rng * 1103515245u + 12345u) >> 16 & 0x7FFF) - 16383) / 16383.0f,
                        (float)((int)((rng = rng * 1103515245u + 12345u) >> 16 & 0x7FFF) - 16383) / 16383.0f
                    ).normalized();
                    break;
                default:
                    disp_dir = face_normal;
            }
        }
        result.set(i, closest_pt + disp_dir * (float)distance);
    }
    return result;
}
} // namespace godot
