#include "gn_native_collision_pop.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

void GNNativeCollisionPop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "velocities",
                                  "ages", "lives", "count",
                                  "ground_y", "bounce", "friction", "kill_below"),
                         &GNNativeCollisionPop::process);
}

Dictionary GNNativeCollisionPop::process(const PackedVector3Array &positions,
                                          const PackedVector3Array &velocities,
                                          const PackedFloat32Array &ages,
                                          const PackedFloat32Array &lives,
                                          int count, double ground_y, double bounce,
                                          double friction, double kill_below) {
    Dictionary result;

    PackedVector3Array out_pos;
    PackedVector3Array out_vel;
    PackedFloat32Array out_ages;
    PackedFloat32Array out_lives;
    out_pos.resize(count);
    out_vel.resize(count);
    out_ages.resize(count);
    out_lives.resize(count);

    const Vector3 *pp = positions.ptr();
    const Vector3 *vp = velocities.ptr();
    const float *ap = ages.ptr();
    const float *lp = lives.ptr();
    Vector3 *op = out_pos.ptrw();
    Vector3 *ov = out_vel.ptrw();
    float *oa = out_ages.ptrw();
    float *ol = out_lives.ptrw();

    int write_idx = 0;
    for (int i = 0; i < count; ++i) {
        Vector3 pos = pp[i];
        if (pos.y < kill_below) continue;

        Vector3 vel = vp[i];
        if (pos.y < ground_y) {
            pos.y = ground_y;
            vel.y = -vel.y * bounce;
            vel.x *= (1.0 - friction);
            vel.z *= (1.0 - friction);
        }

        op[write_idx] = pos;
        ov[write_idx] = vel;
        oa[write_idx] = ap[i];
        ol[write_idx] = lp[i];
        ++write_idx;
    }

    out_pos.resize(write_idx);
    out_vel.resize(write_idx);
    out_ages.resize(write_idx);
    out_lives.resize(write_idx);

    result["positions"] = out_pos;
    result["velocities"] = out_vel;
    result["ages"] = out_ages;
    result["lives"] = out_lives;
    result["count"] = write_idx;
    return result;
}

} // namespace godot
