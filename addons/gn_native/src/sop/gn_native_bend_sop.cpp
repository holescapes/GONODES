#include "gn_native_bend_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeBendSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "angle_rad", "axis_idx",
                                  "min_extent", "max_extent"),
                         &GNNativeBendSop::process);
}

PackedVector3Array GNNativeBendSop::process(const PackedVector3Array &positions,
                                             double angle_rad, int axis_idx,
                                             double min_extent, double max_extent) {
    int count = positions.size();
    PackedVector3Array result;
    result.resize(count);
    const Vector3 *src = positions.ptr();
    Vector3 *dst = result.ptrw();

    // Bend along axis_idx, curving in the perpendicular plane
    int bend_axis = axis_idx;        // axis along which we bend (height)
    int perp1 = (axis_idx + 1) % 3;  // radius direction
    int perp2 = (axis_idx + 2) % 3;  // stays unchanged

    double range = max_extent - min_extent;
    if (std::fabs(range) < 0.0001) range = 0.0001;

    if (std::fabs(angle_rad) < 0.0001) {
        // No bend — pass through
        for (int i = 0; i < count; ++i) dst[i] = src[i];
        return result;
    }

    double radius = range / angle_rad;

    for (int i = 0; i < count; ++i) {
        Vector3 p = src[i];
        double h = (bend_axis == 0) ? p.x : (bend_axis == 1 ? p.y : p.z);
        double r = (perp1 == 0) ? p.x : (perp1 == 1 ? p.y : p.z);

        double t = CLAMP((h - min_extent) / range, 0.0, 1.0);
        double theta = t * angle_rad;

        double new_r = (radius + r) * std::cos(theta) - radius;
        double new_h = (radius + r) * std::sin(theta) + min_extent * (1.0 - t);

        // Non-bent portion: linearly extend beyond the range
        if (h < min_extent) {
            dst[i] = src[i];
            continue;
        }
        if (h > max_extent) {
            // Extrapolate with the rotation at max
            double over = h - max_extent;
            double end_theta = angle_rad;
            double cos_t = std::cos(end_theta);
            double sin_t = std::sin(end_theta);
            double base_r = (radius + r) * cos_t - radius;
            double base_h = (radius + r) * sin_t + min_extent * 0.0;
            new_r = base_r - over * sin_t;
            new_h = base_h + over * cos_t;
        }

        Vector3 out_p = p;
        if (bend_axis == 0) out_p.x = new_h; else if (bend_axis == 1) out_p.y = new_h; else out_p.z = new_h;
        if (perp1 == 0) out_p.x = new_r; else if (perp1 == 1) out_p.y = new_r; else out_p.z = new_r;
        dst[i] = out_p;
    }
    return result;
}

} // namespace godot
