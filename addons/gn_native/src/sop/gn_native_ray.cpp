#include "gn_native_ray.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

using namespace godot;

void GNNativeRay::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "src_positions", "src_normals",
                                  "target_faces", "direction", "max_dist",
                                  "offset", "use_hit_normal"),
                         &GNNativeRay::process);
}

static Vector3 _get_direction(int mode, const Vector3 &normal) {
    switch (mode) {
        case 0: return -normal.normalized();
        case 1: return Vector3(0, -1, 0);
        case 2: return Vector3(0, 1, 0);
        case 3: return Vector3(0, 0, -1);
        case 4: return Vector3(0, 0, 1);
        case 5: return Vector3(-1, 0, 0);
        case 6: return Vector3(1, 0, 0);
        default: return Vector3(0, -1, 0);
    }
}

Dictionary GNNativeRay::process(const PackedVector3Array &src_positions,
                                 const PackedVector3Array &src_normals,
                                 const PackedVector3Array &target_faces,
                                 int direction, double max_dist, double offset,
                                 bool use_hit_normal) {
    int vert_count = src_positions.size();
    int tri_count = target_faces.size() / 3;

    PackedVector3Array out_positions;
    PackedVector3Array out_normals;
    out_positions.resize(vert_count);
    out_normals.resize(vert_count);

    const Vector3 *src_pos = src_positions.ptr();
    const Vector3 *src_nrm = src_normals.ptr();
    const Vector3 *faces = target_faces.ptr();
    Vector3 *dst_pos = out_positions.ptrw();
    Vector3 *dst_nrm = out_normals.ptrw();

    const float eps = 1e-8f;

    for (int vi = 0; vi < vert_count; ++vi) {
        Vector3 origin = src_pos[vi];
        Vector3 normal = (vi < (int)src_normals.size()) ? src_nrm[vi] : Vector3(0, 1, 0);
        Vector3 dir = _get_direction(direction, normal);

        float best_t = (float)max_dist;
        Vector3 best_pos = origin;
        Vector3 best_normal = normal;
        bool hit_found = false;

        // Möller–Trumbore ray-triangle intersection
        for (int ti = 0; ti < tri_count; ++ti) {
            Vector3 v0 = faces[ti * 3];
            Vector3 v1 = faces[ti * 3 + 1];
            Vector3 v2 = faces[ti * 3 + 2];

            Vector3 e1 = v1 - v0;
            Vector3 e2 = v2 - v0;
            Vector3 h = dir.cross(e2);
            float a = e1.dot(h);
            if (std::fabs(a) < eps) continue;

            float f = 1.0f / a;
            Vector3 s = origin - v0;
            float u = f * s.dot(h);
            if (u < 0.0f || u > 1.0f) continue;

            Vector3 q = s.cross(e1);
            float v = f * dir.dot(q);
            if (v < 0.0f || u + v > 1.0f) continue;

            float t = f * e2.dot(q);
            if (t > eps && t < best_t) {
                best_t = t;
                best_pos = origin + dir * t;
                best_normal = e1.cross(e2).normalized();
                hit_found = true;
            }
        }

        if (hit_found) {
            dst_pos[vi] = best_pos + best_normal * (float)offset;
            dst_nrm[vi] = use_hit_normal ? best_normal : normal;
        } else {
            dst_pos[vi] = origin;
            dst_nrm[vi] = normal;
        }
    }

    Dictionary result;
    result["positions"] = out_positions;
    result["normals"] = out_normals;
    return result;
}
