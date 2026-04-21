#include "gn_native_project_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <cmath>
#include <cfloat>
namespace godot {
void GNNativeProjectSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "source_pts", "target_verts", "target_indices", "axis"),
                         &GNNativeProjectSop::process);
}
// Moller-Trumbore ray-triangle intersection
static bool ray_tri(const Vector3 &origin, const Vector3 &dir,
                     const Vector3 &v0, const Vector3 &v1, const Vector3 &v2,
                     double &t) {
    const double EPSILON = 1e-8;
    Vector3 e1 = v1 - v0, e2 = v2 - v0;
    Vector3 h = dir.cross(e2);
    double a = e1.dot(h);
    if (a > -EPSILON && a < EPSILON) return false;
    double f = 1.0 / a;
    Vector3 s = origin - v0;
    double u = f * s.dot(h);
    if (u < 0.0 || u > 1.0) return false;
    Vector3 q = s.cross(e1);
    double v = f * dir.dot(q);
    if (v < 0.0 || u + v > 1.0) return false;
    t = f * e2.dot(q);
    return t > EPSILON;
}
PackedVector3Array GNNativeProjectSop::process(const PackedVector3Array &source_pts,
        const PackedVector3Array &target_verts, const PackedInt32Array &target_indices,
        int axis) {
    int src_count = source_pts.size();
    int tri_count = target_indices.size() / 3;
    int tgt_count = target_verts.size();
    PackedVector3Array result;
    result.resize(src_count);
    Vector3 ray_dir;
    switch (axis) {
        case 0: ray_dir = Vector3(1, 0, 0); break;
        case 1: ray_dir = Vector3(0, 1, 0); break;
        default: ray_dir = Vector3(0, 0, 1); break;
    }
    const Vector3 *sv = source_pts.ptr();
    const Vector3 *tv = target_verts.ptr();
    const int *ti = target_indices.ptr();
    for (int i = 0; i < src_count; ++i) {
        Vector3 p = sv[i];
        double best_t = DBL_MAX;
        bool hit = false;
        // Try both directions
        for (int sign = -1; sign <= 1; sign += 2) {
            Vector3 dir = ray_dir * (double)sign;
            for (int t = 0; t < tri_count; ++t) {
                int i0 = ti[t*3], i1 = ti[t*3+1], i2 = ti[t*3+2];
                if (i0 >= tgt_count || i1 >= tgt_count || i2 >= tgt_count) continue;
                double tt;
                if (ray_tri(p, dir, tv[i0], tv[i1], tv[i2], tt)) {
                    if (tt < best_t) {
                        best_t = tt;
                        Vector3 hit_pt = p + dir * tt;
                        result.set(i, hit_pt);
                        hit = true;
                    }
                }
            }
        }
        if (!hit) {
            // Fallback: flatten on axis
            Vector3 flat = p;
            switch (axis) {
                case 0: flat.x = 0; break;
                case 1: flat.y = 0; break;
                default: flat.z = 0; break;
            }
            result.set(i, flat);
        }
    }
    return result;
}
} // namespace godot
