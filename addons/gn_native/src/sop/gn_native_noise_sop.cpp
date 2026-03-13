#include "gn_native_noise_sop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeNoiseSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "normals",
                                  "amplitude", "frequency",
                                  "offset_x", "offset_y", "offset_z",
                                  "time_offset", "axis_mode", "seed"),
                         &GNNativeNoiseSop::process);
}

// Simple 3D value noise using hash
static double _hash3(double x, double y, double z) {
    double n = std::sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453;
    return n - std::floor(n);
}

static double _smooth_noise_3d(double x, double y, double z) {
    double ix = std::floor(x), iy = std::floor(y), iz = std::floor(z);
    double fx = x - ix, fy = y - iy, fz = z - iz;
    double ux = fx * fx * (3.0 - 2.0 * fx);
    double uy = fy * fy * (3.0 - 2.0 * fy);
    double uz = fz * fz * (3.0 - 2.0 * fz);

    double v000 = _hash3(ix, iy, iz);
    double v100 = _hash3(ix + 1, iy, iz);
    double v010 = _hash3(ix, iy + 1, iz);
    double v110 = _hash3(ix + 1, iy + 1, iz);
    double v001 = _hash3(ix, iy, iz + 1);
    double v101 = _hash3(ix + 1, iy, iz + 1);
    double v011 = _hash3(ix, iy + 1, iz + 1);
    double v111 = _hash3(ix + 1, iy + 1, iz + 1);

    double x00 = v000 * (1 - ux) + v100 * ux;
    double x10 = v010 * (1 - ux) + v110 * ux;
    double x01 = v001 * (1 - ux) + v101 * ux;
    double x11 = v011 * (1 - ux) + v111 * ux;
    double xy0 = x00 * (1 - uy) + x10 * uy;
    double xy1 = x01 * (1 - uy) + x11 * uy;
    return (xy0 * (1 - uz) + xy1 * uz) * 2.0 - 1.0;
}

PackedVector3Array GNNativeNoiseSop::process(const PackedVector3Array &positions,
                                              const PackedVector3Array &normals,
                                              double amplitude, double frequency,
                                              double offset_x, double offset_y,
                                              double offset_z, double time_offset,
                                              int axis_mode, int seed) {
    int count = positions.size();
    PackedVector3Array result;
    result.resize(count);
    const Vector3 *pos = positions.ptr();
    const Vector3 *nrm = normals.ptr();
    int nrm_count = normals.size();
    Vector3 *out = result.ptrw();

    double seed_off = seed * 13.37;

    for (int i = 0; i < count; ++i) {
        Vector3 p = pos[i];
        double sx = (p.x + offset_x + time_offset + seed_off) * frequency;
        double sy = (p.y + offset_y + seed_off) * frequency;
        double sz = (p.z + offset_z + seed_off) * frequency;
        double n = _smooth_noise_3d(sx, sy, sz) * amplitude;

        switch (axis_mode) {
            case 0: // Normal
                if (i < nrm_count)
                    out[i] = p + nrm[i] * n;
                else
                    out[i] = p + Vector3(0, n, 0);
                break;
            case 1: out[i] = p + Vector3(n, 0, 0); break;
            case 2: out[i] = p + Vector3(0, n, 0); break;
            case 3: out[i] = p + Vector3(0, 0, n); break;
            default: out[i] = p; break;
        }
    }

    return result;
}

} // namespace godot
