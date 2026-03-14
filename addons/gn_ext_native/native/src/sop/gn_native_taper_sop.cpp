#include "gn_native_taper_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeTaperSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "taper_amount", "axis_idx",
                                  "min_extent", "max_extent"),
                         &GNNativeTaperSop::process);
}

PackedVector3Array GNNativeTaperSop::process(const PackedVector3Array &positions,
                                              double taper_amount, int axis_idx,
                                              double min_extent, double max_extent) {
    int count = positions.size();
    PackedVector3Array result;
    result.resize(count);
    const Vector3 *src = positions.ptr();
    Vector3 *dst = result.ptrw();

    int perp1 = (axis_idx + 1) % 3;
    int perp2 = (axis_idx + 2) % 3;
    double range = max_extent - min_extent;
    if (std::fabs(range) < 0.0001) range = 0.0001;

    for (int i = 0; i < count; ++i) {
        Vector3 p = src[i];
        double axis_val = (axis_idx == 0) ? p.x : (axis_idx == 1 ? p.y : p.z);
        double t = CLAMP((axis_val - min_extent) / range, 0.0, 1.0);
        // Scale goes from 1.0 at min to (1.0 + taper_amount) at max
        double scale = 1.0 + taper_amount * t;

        Vector3 out_p = p;
        if (perp1 == 0) out_p.x *= scale; else if (perp1 == 1) out_p.y *= scale; else out_p.z *= scale;
        if (perp2 == 0) out_p.x *= scale; else if (perp2 == 1) out_p.y *= scale; else out_p.z *= scale;
        dst[i] = out_p;
    }
    return result;
}

} // namespace godot
