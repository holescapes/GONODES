#include "gn_native_attract_pop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeAttractPop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "velocities",
                                  "target_x", "target_y", "target_z",
                                  "strength", "radius", "dt"),
                         &GNNativeAttractPop::process);
}

PackedVector3Array GNNativeAttractPop::process(const PackedVector3Array &positions,
                                                const PackedVector3Array &velocities,
                                                double target_x, double target_y,
                                                double target_z,
                                                double strength, double radius,
                                                double dt) {
    int count = positions.size();
    PackedVector3Array out_vel;
    out_vel.resize(count);
    const Vector3 *pos = positions.ptr();
    const Vector3 *vel = velocities.ptr();
    Vector3 *ov = out_vel.ptrw();
    Vector3 target(target_x, target_y, target_z);

    for (int i = 0; i < count; ++i) {
        Vector3 diff = target - pos[i];
        double dist = diff.length();
        ov[i] = vel[i];
        if (dist < 0.001) continue;
        if (radius > 0.0 && dist > radius) continue;
        double force_mag = strength / MAX(dist * dist, 0.01);
        ov[i] = vel[i] + diff.normalized() * force_mag * dt;
    }

    return out_vel;
}

} // namespace godot
