#include "gn_native_limit_pop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeLimitPop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "velocities",
                                  "ages", "lives", "count",
                                  "bbox_min_x", "bbox_min_y", "bbox_min_z",
                                  "bbox_max_x", "bbox_max_y", "bbox_max_z",
                                  "max_speed", "kill_outside"),
                         &GNNativeLimitPop::process);
}

Dictionary GNNativeLimitPop::process(const PackedVector3Array &positions,
                                      const PackedVector3Array &velocities,
                                      const PackedFloat32Array &ages,
                                      const PackedFloat32Array &lives,
                                      int count,
                                      double bbox_min_x, double bbox_min_y,
                                      double bbox_min_z,
                                      double bbox_max_x, double bbox_max_y,
                                      double bbox_max_z,
                                      double max_speed, bool kill_outside) {
    Dictionary result;

    PackedVector3Array out_pos, out_vel;
    PackedFloat32Array out_ages, out_lives;
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

        if (kill_outside) {
            if (pos.x < bbox_min_x || pos.x > bbox_max_x ||
                pos.y < bbox_min_y || pos.y > bbox_max_y ||
                pos.z < bbox_min_z || pos.z > bbox_max_z) {
                continue;
            }
        }

        Vector3 vel = vp[i];
        if (max_speed > 0.0) {
            double spd = vel.length();
            if (spd > max_speed) {
                vel = vel * (max_speed / spd);
            }
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
