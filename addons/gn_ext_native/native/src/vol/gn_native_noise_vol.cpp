#include "gn_native_noise_vol.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeNoiseVol::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "res_x", "res_y", "res_z",
                                  "frequency", "amplitude",
                                  "offset_x", "offset_y", "offset_z",
                                  "time_val", "lacunarity", "gain",
                                  "octaves", "seed"),
                         &GNNativeNoiseVol::process);
}

// Simple 3D hash noise
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

static double _fbm_3d(double x, double y, double z, int octaves,
                       double lacunarity, double gain) {
    double value = 0.0;
    double amp = 1.0;
    double freq = 1.0;
    for (int o = 0; o < octaves; ++o) {
        value += _smooth_noise_3d(x * freq, y * freq, z * freq) * amp;
        freq *= lacunarity;
        amp *= gain;
    }
    return value;
}

PackedFloat32Array GNNativeNoiseVol::process(int res_x, int res_y, int res_z,
                                              double frequency, double amplitude,
                                              double offset_x, double offset_y,
                                              double offset_z, double time_val,
                                              double lacunarity, double gain,
                                              int octaves, int seed) {
    int total = res_x * res_y * res_z;
    PackedFloat32Array out;
    out.resize(total);
    float *p = out.ptrw();

    double seed_off = seed * 13.37;

    for (int z = 0; z < res_z; ++z) {
        for (int y = 0; y < res_y; ++y) {
            for (int x = 0; x < res_x; ++x) {
                double nx = (double)x / (double)res_x + offset_x + seed_off;
                double ny = (double)y / (double)res_y + offset_y + seed_off;
                double nz = (double)z / (double)res_z + offset_z + time_val + seed_off;
                double v = _fbm_3d(nx * frequency, ny * frequency, nz * frequency,
                                   octaves, lacunarity, gain) * amplitude;
                p[z * res_y * res_x + y * res_x + x] = (float)v;
            }
        }
    }

    return out;
}

} // namespace godot
