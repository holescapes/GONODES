#include "gn_native_twist_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeTwistSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "angle_rad", "axis_idx",
                                  "min_extent", "max_extent"),
                         &GNNativeTwistSop::process);
}

PackedVector3Array GNNativeTwistSop::process(const PackedVector3Array &positions,
                                              double angle_rad, int axis_idx,
                                              double min_extent, double max_extent) {
    int count = positions.size();
    PackedVector3Array result;
    result.resize(count);
    const Vector3 *src = positions.ptr();
    Vector3 *dst = result.ptrw();

    int perp1 = (axis_idx + 1) % 3;
    int perp2 = (axis_idx + 2) % 3;
    double range = max_extent - min_extent;
    if (range < 0.0001) range = 0.0001;

    for (int i = 0; i < count; ++i) {
        Vector3 p = src[i];
        double axis_val = (axis_idx == 0) ? p.x : (axis_idx == 1 ? p.y : p.z);
        double t = CLAMP((axis_val - min_extent) / range, 0.0, 1.0);
        double theta = t * angle_rad;
        double cs = std::cos(theta);
        double sn = std::sin(theta);

        double a = (perp1 == 0) ? p.x : (perp1 == 1 ? p.y : p.z);
        double b = (perp2 == 0) ? p.x : (perp2 == 1 ? p.y : p.z);

        double ra = a * cs - b * sn;
        double rb = a * sn + b * cs;

        Vector3 out_p = p;
        if (perp1 == 0) out_p.x = ra; else if (perp1 == 1) out_p.y = ra; else out_p.z = ra;
        if (perp2 == 0) out_p.x = rb; else if (perp2 == 1) out_p.y = rb; else out_p.z = rb;
        dst[i] = out_p;
    }
    return result;
}

} // namespace godot
