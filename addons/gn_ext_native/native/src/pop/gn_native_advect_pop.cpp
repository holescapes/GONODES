#include "gn_native_advect_pop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeAdvectPop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "velocities",
                                  "vol_data", "vol_rx", "vol_ry", "vol_rz", "vol_ch",
                                  "bounds_x", "bounds_y", "bounds_z",
                                  "bounds_sx", "bounds_sy", "bounds_sz",
                                  "strength", "dt", "add_mode"),
                         &GNNativeAdvectPop::process);
}

PackedVector3Array GNNativeAdvectPop::process(const PackedVector3Array &positions,
                                               const PackedVector3Array &velocities,
                                               const PackedFloat32Array &vol_data,
                                               int vol_rx, int vol_ry, int vol_rz,
                                               int vol_ch,
                                               double bounds_x, double bounds_y,
                                               double bounds_z,
                                               double bounds_sx, double bounds_sy,
                                               double bounds_sz,
                                               double strength, double dt,
                                               bool add_mode) {
    int count = positions.size();
    PackedVector3Array out_vel;
    out_vel.resize(count);
    const Vector3 *pos = positions.ptr();
    const Vector3 *vel = velocities.ptr();
    Vector3 *ov = out_vel.ptrw();
    const float *vd = vol_data.ptr();
    int vd_size = vol_data.size();

    for (int i = 0; i < count; ++i) {
        Vector3 p = pos[i];
        // Map to volume UV [0,1]
        double uvx = CLAMP((p.x - bounds_x) / bounds_sx, 0.0, 1.0);
        double uvy = CLAMP((p.y - bounds_y) / bounds_sy, 0.0, 1.0);
        double uvz = CLAMP((p.z - bounds_z) / bounds_sz, 0.0, 1.0);

        int xi = CLAMP((int)(uvx * (vol_rx - 1)), 0, vol_rx - 1);
        int yi = CLAMP((int)(uvy * (vol_ry - 1)), 0, vol_ry - 1);
        int zi = CLAMP((int)(uvz * (vol_rz - 1)), 0, vol_rz - 1);
        int base = (zi * vol_ry * vol_rx + yi * vol_rx + xi) * vol_ch;

        Vector3 field_vel(0, 0, 0);
        if (vol_ch >= 3 && base + 2 < vd_size) {
            field_vel = Vector3(vd[base], vd[base + 1], vd[base + 2]);
        }

        if (add_mode) {
            ov[i] = vel[i] + field_vel * strength * dt;
        } else {
            ov[i] = field_vel * strength;
        }
    }

    return out_vel;
}

} // namespace godot
