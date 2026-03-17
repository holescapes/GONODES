#include "gn_native_force_pop.h"

#include <godot_cpp/core/class_db.hpp>

namespace godot {

void GNNativeForcePop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "velocities",
                                  "count", "fx", "fy", "fz", "drag", "dt"),
                         &GNNativeForcePop::process);
}

Dictionary GNNativeForcePop::process(const PackedVector3Array &positions,
                                      const PackedVector3Array &velocities,
                                      int count, double fx, double fy, double fz,
                                      double drag, double dt) {
    Dictionary result;
    PackedVector3Array out_pos, out_vel;
    out_pos.resize(count);
    out_vel.resize(count);
    const Vector3 *pp = positions.ptr();
    const Vector3 *vp = velocities.ptr();
    Vector3 *op = out_pos.ptrw();
    Vector3 *ov = out_vel.ptrw();

    Vector3 force(fx, fy, fz);
    double drag_factor = 1.0 - drag * dt;

    for (int i = 0; i < count; ++i) {
        Vector3 vel = vp[i] + force * dt;
        vel *= drag_factor;
        op[i] = pp[i] + vel * dt;
        ov[i] = vel;
    }

    result["positions"] = out_pos;
    result["velocities"] = out_vel;
    return result;
}

} // namespace godot
