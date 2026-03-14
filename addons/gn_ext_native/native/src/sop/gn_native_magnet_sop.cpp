#include "gn_native_magnet_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeMagnetSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "magnet_pos", "radius",
                                  "strength", "falloff_type"),
                         &GNNativeMagnetSop::process);
}

PackedVector3Array GNNativeMagnetSop::process(const PackedVector3Array &positions,
                                               const Vector3 &magnet_pos,
                                               double radius, double strength,
                                               int falloff_type) {
    int count = positions.size();
    PackedVector3Array result;
    result.resize(count);
    const Vector3 *src = positions.ptr();
    Vector3 *dst = result.ptrw();

    double r2 = radius * radius;
    if (radius < 0.0001) {
        for (int i = 0; i < count; ++i) dst[i] = src[i];
        return result;
    }

    for (int i = 0; i < count; ++i) {
        Vector3 p = src[i];
        Vector3 delta = magnet_pos - p;
        double dist2 = delta.length_squared();

        if (dist2 >= r2) {
            dst[i] = p;
            continue;
        }

        double dist = std::sqrt(dist2);
        double t = dist / radius; // 0 at center, 1 at boundary

        double falloff;
        switch (falloff_type) {
            case 1: falloff = 1.0 - t * t; break;           // Quadratic
            case 2: falloff = t * t * (3.0 - 2.0 * t);      // Smooth step (inverted)
                    falloff = 1.0 - falloff; break;
            default: falloff = 1.0 - t; break;               // Linear
        }

        Vector3 dir = dist > 0.0001 ? delta / dist : Vector3(0, 1, 0);
        dst[i] = p + dir * (strength * falloff);
    }
    return result;
}

} // namespace godot
