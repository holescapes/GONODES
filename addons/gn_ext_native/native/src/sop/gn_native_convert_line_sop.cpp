#include "gn_native_convert_line_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector3.hpp>
namespace godot {
void GNNativeConvertLineSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "points", "mode", "segments", "tension", "closed"),
                         &GNNativeConvertLineSop::process);
}
PackedVector3Array GNNativeConvertLineSop::process(const PackedVector3Array &points,
        int mode, int segments, double tension, bool closed) {
    int n = points.size();
    if (n < 2) return points;
    const Vector3 *pts = points.ptr();
    PackedVector3Array result;
    if (mode == 0) {
        // Polyline passthrough
        result = points;
        if (closed && n > 2) result.push_back(pts[0]);
        return result;
    }
    if (mode == 1) {
        // Catmull-Rom spline
        int segs = segments > 1 ? segments : 8;
        int total_pts = closed ? n : n - 1;
        for (int i = 0; i < total_pts; ++i) {
            Vector3 p0 = pts[(i - 1 + n) % n];
            Vector3 p1 = pts[i];
            Vector3 p2 = pts[(i + 1) % n];
            Vector3 p3 = pts[(i + 2) % n];
            // Clamp endpoints for non-closed
            if (!closed) {
                if (i == 0) p0 = p1;
                if (i >= n - 2) p3 = p2;
            }
            for (int s = 0; s < segs; ++s) {
                double t = (double)s / (double)segs;
                double t2 = t * t, t3 = t2 * t;
                double tau = tension;
                // Catmull-Rom matrix with tension
                Vector3 v = p1 +
                    (p2 - p0) * (tau * t) +
                    (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * (tau * t2) +
                    (-p0 + p1 * 3.0 - p2 * 3.0 + p3) * (tau * t3);
                result.push_back(v);
            }
        }
        result.push_back(closed ? pts[0] : pts[n - 1]);
        return result;
    }
    // Mode 2: Chaikin subdivision
    PackedVector3Array current = points;
    int iterations = segments > 0 ? segments : 2;
    for (int iter = 0; iter < iterations; ++iter) {
        int cn = current.size();
        if (cn < 2) break;
        PackedVector3Array next;
        const Vector3 *cp = current.ptr();
        int limit = closed ? cn : cn - 1;
        for (int i = 0; i < limit; ++i) {
            Vector3 a = cp[i];
            Vector3 b = cp[(i + 1) % cn];
            next.push_back(a * 0.75f + b * 0.25f);
            next.push_back(a * 0.25f + b * 0.75f);
        }
        if (!closed && cn > 0) {
            // Keep endpoints
            next.set(0, cp[0]);
            next.push_back(cp[cn - 1]);
        }
        current = next;
    }
    if (closed && current.size() > 0) current.push_back(current[0]);
    return current;
}
} // namespace godot
