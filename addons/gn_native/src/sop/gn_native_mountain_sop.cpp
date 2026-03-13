#include "gn_native_mountain_sop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeMountainSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "normals", "height",
                                  "frequency", "octaves", "roughness", "seed"),
                         &GNNativeMountainSop::process);
}

static double _hash3(double x, double y, double z) {
    double n = std::sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453;
    return n - std::floor(n);
}

static double _smooth3d(double x, double y, double z) {
    double ix = std::floor(x), iy = std::floor(y), iz = std::floor(z);
    double fx = x - ix, fy = y - iy, fz = z - iz;
    double ux = fx * fx * (3.0 - 2.0 * fx);
    double uy = fy * fy * (3.0 - 2.0 * fy);
    double uz = fz * fz * (3.0 - 2.0 * fz);
    double v000 = _hash3(ix, iy, iz), v100 = _hash3(ix+1, iy, iz);
    double v010 = _hash3(ix, iy+1, iz), v110 = _hash3(ix+1, iy+1, iz);
    double v001 = _hash3(ix, iy, iz+1), v101 = _hash3(ix+1, iy, iz+1);
    double v011 = _hash3(ix, iy+1, iz+1), v111 = _hash3(ix+1, iy+1, iz+1);
    double x00 = v000*(1-ux)+v100*ux, x10 = v010*(1-ux)+v110*ux;
    double x01 = v001*(1-ux)+v101*ux, x11 = v011*(1-ux)+v111*ux;
    double xy0 = x00*(1-uy)+x10*uy, xy1 = x01*(1-uy)+x11*uy;
    return (xy0*(1-uz)+xy1*uz)*2.0-1.0;
}

PackedVector3Array GNNativeMountainSop::process(const PackedVector3Array &positions,
                                                 const PackedVector3Array &normals,
                                                 double height, double frequency,
                                                 int octaves, double roughness, int seed) {
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
        double amp = 1.0, freq = frequency, total_amp = 0.0, value = 0.0;
        for (int o = 0; o < octaves; ++o) {
            value += amp * _smooth3d((p.x + seed_off) * freq,
                                     (p.y + seed_off) * freq,
                                     (p.z + seed_off) * freq);
            total_amp += amp;
            amp *= roughness;
            freq *= 2.0;
        }
        if (total_amp > 0) value /= total_amp;
        double disp = value * height;
        if (i < nrm_count)
            out[i] = p + nrm[i] * disp;
        else
            out[i] = p + Vector3(0, disp, 0);
    }
    return result;
}

} // namespace godot
