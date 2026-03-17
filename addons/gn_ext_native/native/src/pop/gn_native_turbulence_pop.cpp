#include "gn_native_turbulence_pop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeTurbulencePop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "velocities",
                                  "count", "amplitude", "frequency",
                                  "time_val", "roughness", "octaves", "dt"),
                         &GNNativeTurbulencePop::process);
}

// Simple 3D hash noise for curl computation
static double _noise_hash3(double x, double y, double z) {
    double n = std::sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453;
    return n - std::floor(n);
}

static double _smooth_noise(double x, double y, double z) {
    double ix = std::floor(x), iy = std::floor(y), iz = std::floor(z);
    double fx = x - ix, fy = y - iy, fz = z - iz;
    double ux = fx * fx * (3.0 - 2.0 * fx);
    double uy = fy * fy * (3.0 - 2.0 * fy);
    double uz = fz * fz * (3.0 - 2.0 * fz);

    double v000 = _noise_hash3(ix, iy, iz);
    double v100 = _noise_hash3(ix + 1, iy, iz);
    double v010 = _noise_hash3(ix, iy + 1, iz);
    double v110 = _noise_hash3(ix + 1, iy + 1, iz);
    double v001 = _noise_hash3(ix, iy, iz + 1);
    double v101 = _noise_hash3(ix + 1, iy, iz + 1);
    double v011 = _noise_hash3(ix, iy + 1, iz + 1);
    double v111 = _noise_hash3(ix + 1, iy + 1, iz + 1);

    double x00 = v000 * (1 - ux) + v100 * ux;
    double x10 = v010 * (1 - ux) + v110 * ux;
    double x01 = v001 * (1 - ux) + v101 * ux;
    double x11 = v011 * (1 - ux) + v111 * ux;
    double xy0 = x00 * (1 - uy) + x10 * uy;
    double xy1 = x01 * (1 - uy) + x11 * uy;
    return (xy0 * (1 - uz) + xy1 * uz) * 2.0 - 1.0;
}

static double _fbm(double x, double y, double z, int octaves, double gain) {
    double val = 0.0, amp = 1.0, freq = 1.0;
    for (int o = 0; o < octaves; ++o) {
        val += _smooth_noise(x * freq, y * freq, z * freq) * amp;
        freq *= 2.0;
        amp *= gain;
    }
    return val;
}

PackedVector3Array GNNativeTurbulencePop::process(const PackedVector3Array &positions,
                                                   const PackedVector3Array &velocities,
                                                   int count, double amplitude,
                                                   double frequency, double time_val,
                                                   double roughness, int octaves,
                                                   double dt) {
    PackedVector3Array out_vel;
    out_vel.resize(count);
    const Vector3 *pp = positions.ptr();
    const Vector3 *vp = velocities.ptr();
    Vector3 *ov = out_vel.ptrw();

    const double eps = 0.01;

    for (int i = 0; i < count; ++i) {
        Vector3 p = pp[i];
        double px = p.x * frequency, py = p.y * frequency, pz = p.z * frequency + time_val;

        // Curl noise via finite differences
        double n_x0 = _fbm(px + eps, py, pz, octaves, roughness);
        double n_x1 = _fbm(px - eps, py, pz, octaves, roughness);
        double n_y0 = _fbm(px, py + eps, pz, octaves, roughness);
        double n_y1 = _fbm(px, py - eps, pz, octaves, roughness);
        double n_z0 = _fbm(px, py, pz + eps, octaves, roughness);
        double n_z1 = _fbm(px, py, pz - eps, octaves, roughness);

        double inv_2eps = 1.0 / (2.0 * eps);
        Vector3 curl(
            ((n_y0 - n_y1) - (n_z0 - n_z1)) * inv_2eps,
            ((n_z0 - n_z1) - (n_x0 - n_x1)) * inv_2eps,
            ((n_x0 - n_x1) - (n_y0 - n_y1)) * inv_2eps
        );

        ov[i] = vp[i] + curl * amplitude * dt;
    }

    return out_vel;
}

} // namespace godot
