#include "gn_native_lattice_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <vector>

namespace godot {

void GNNativeLatticeSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "lattice_points",
                                  "sx", "sy", "sz", "bbox_min", "bbox_max"),
                         &GNNativeLatticeSop::process);
}

// Bernstein basis polynomial
static double _bernstein(int n, int k, double t) {
    // Binomial coefficient
    double binom = 1.0;
    for (int i = 0; i < k; ++i) binom *= (double)(n - i) / (double)(i + 1);
    return binom * std::pow(t, k) * std::pow(1.0 - t, n - k);
}

PackedVector3Array GNNativeLatticeSop::process(const PackedVector3Array &positions,
                                                const PackedVector3Array &lattice_points,
                                                int sx, int sy, int sz,
                                                const Vector3 &bbox_min,
                                                const Vector3 &bbox_max) {
    int count = positions.size();
    PackedVector3Array result;
    result.resize(count);
    const Vector3 *src = positions.ptr();
    const Vector3 *lp = lattice_points.ptr();
    Vector3 *dst = result.ptrw();

    Vector3 extent = bbox_max - bbox_min;
    if (extent.x < 0.0001) extent.x = 0.0001;
    if (extent.y < 0.0001) extent.y = 0.0001;
    if (extent.z < 0.0001) extent.z = 0.0001;

    int nx = sx - 1, ny = sy - 1, nz = sz - 1;

    for (int vi = 0; vi < count; ++vi) {
        Vector3 p = src[vi];
        // Normalize to [0,1] within bounding box
        double u = CLAMP((p.x - bbox_min.x) / extent.x, 0.0, 1.0);
        double v = CLAMP((p.y - bbox_min.y) / extent.y, 0.0, 1.0);
        double w = CLAMP((p.z - bbox_min.z) / extent.z, 0.0, 1.0);

        // Evaluate FFD using Bernstein polynomials
        Vector3 deformed(0, 0, 0);
        for (int iz = 0; iz < sz; ++iz) {
            double bz = _bernstein(nz, iz, w);
            for (int iy = 0; iy < sy; ++iy) {
                double by = _bernstein(ny, iy, v);
                for (int ix = 0; ix < sx; ++ix) {
                    double bx = _bernstein(nx, ix, u);
                    int idx = iz * sy * sx + iy * sx + ix;
                    if (idx < lattice_points.size()) {
                        deformed += lp[idx] * (bx * by * bz);
                    }
                }
            }
        }
        dst[vi] = deformed;
    }
    return result;
}

} // namespace godot
