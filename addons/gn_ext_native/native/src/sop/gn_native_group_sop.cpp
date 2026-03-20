#include "gn_native_group_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>

using namespace godot;

void GNNativeGroupSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("group_by_bbox", "positions", "min", "max"), &GNNativeGroupSop::group_by_bbox);
    ClassDB::bind_method(D_METHOD("group_by_normal", "normals", "direction", "angle_deg"), &GNNativeGroupSop::group_by_normal);
}

PackedFloat32Array GNNativeGroupSop::group_by_bbox(const PackedVector3Array &p_positions,
                                                     const Vector3 &p_min, const Vector3 &p_max) const {
    int count = p_positions.size();
    PackedFloat32Array out;
    out.resize(count);
    if (count == 0) return out;

    const Vector3 *pos = p_positions.ptr();
    float *dst = out.ptrw();

    for (int i = 0; i < count; i++) {
        const Vector3 &p = pos[i];
        dst[i] = (p.x >= p_min.x && p.x <= p_max.x &&
                   p.y >= p_min.y && p.y <= p_max.y &&
                   p.z >= p_min.z && p.z <= p_max.z) ? 1.0f : 0.0f;
    }
    return out;
}

PackedFloat32Array GNNativeGroupSop::group_by_normal(const PackedVector3Array &p_normals,
                                                       const Vector3 &p_direction,
                                                       double p_angle_deg) const {
    int count = p_normals.size();
    PackedFloat32Array out;
    out.resize(count);
    if (count == 0) return out;

    const Vector3 *nrm = p_normals.ptr();
    float *dst = out.ptrw();
    double cos_thresh = std::cos(p_angle_deg * Math_PI / 180.0);
    Vector3 dir = p_direction.normalized();

    for (int i = 0; i < count; i++) {
        Vector3 n = nrm[i].normalized();
        double d = n.x * dir.x + n.y * dir.y + n.z * dir.z;
        dst[i] = (d >= cos_thresh) ? 1.0f : 0.0f;
    }
    return out;
}
