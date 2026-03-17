#include "gn_native_displace_vol.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeDisplaceVol::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "density", "velocity",
                                  "res_x", "res_y", "res_z",
                                  "den_ch", "vel_ch", "strength"),
                         &GNNativeDisplaceVol::process);
}

static float _trilinear(const float *data, double u, double v, double w,
                         int rx, int ry, int rz, int ch) {
    // Clamp UVW to [0,1)
    u = CLAMP(u, 0.0, 0.9999);
    v = CLAMP(v, 0.0, 0.9999);
    w = CLAMP(w, 0.0, 0.9999);

    double fx = u * (rx - 1), fy = v * (ry - 1), fz = w * (rz - 1);
    int x0 = (int)fx, y0 = (int)fy, z0 = (int)fz;
    int x1 = MIN(x0 + 1, rx - 1), y1 = MIN(y0 + 1, ry - 1), z1 = MIN(z0 + 1, rz - 1);
    double dx = fx - x0, dy = fy - y0, dz = fz - z0;

    auto idx = [&](int x, int y, int z) { return (z * ry * rx + y * rx + x) * ch; };

    float c000 = data[idx(x0, y0, z0)];
    float c100 = data[idx(x1, y0, z0)];
    float c010 = data[idx(x0, y1, z0)];
    float c110 = data[idx(x1, y1, z0)];
    float c001 = data[idx(x0, y0, z1)];
    float c101 = data[idx(x1, y0, z1)];
    float c011 = data[idx(x0, y1, z1)];
    float c111 = data[idx(x1, y1, z1)];

    float a = c000 * (1 - dx) + c100 * dx;
    float b = c010 * (1 - dx) + c110 * dx;
    float c = c001 * (1 - dx) + c101 * dx;
    float d = c011 * (1 - dx) + c111 * dx;
    float e = a * (1 - dy) + b * dy;
    float f = c * (1 - dy) + d * dy;
    return e * (1 - dz) + f * dz;
}

PackedFloat32Array GNNativeDisplaceVol::process(const PackedFloat32Array &density,
                                                 const PackedFloat32Array &velocity,
                                                 int res_x, int res_y, int res_z,
                                                 int den_ch, int vel_ch,
                                                 double strength) {
    int total = res_x * res_y * res_z * den_ch;
    PackedFloat32Array out;
    out.resize(total);
    float *op = out.ptrw();
    const float *den = density.ptr();
    const float *vel = velocity.ptr();
    int vel_size = velocity.size();

    for (int z = 0; z < res_z; ++z) {
        for (int y = 0; y < res_y; ++y) {
            for (int x = 0; x < res_x; ++x) {
                int vidx = (z * res_y * res_x + y * res_x + x) * vel_ch;
                float vx = (vidx < vel_size) ? vel[vidx] : 0.0f;
                float vy = (vidx + 1 < vel_size) ? vel[vidx + 1] : 0.0f;
                float vz = (vidx + 2 < vel_size) ? vel[vidx + 2] : 0.0f;

                double u = (double)x / (double)res_x - vx * strength;
                double v = (double)y / (double)res_y - vy * strength;
                double w = (double)z / (double)res_z - vz * strength;

                int oidx = (z * res_y * res_x + y * res_x + x) * den_ch;
                op[oidx] = _trilinear(den, u, v, w, res_x, res_y, res_z, den_ch);
            }
        }
    }

    return out;
}

} // namespace godot
