#include "gn_native_fluid_vol.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeFluidVol::_bind_methods() {
    ClassDB::bind_method(D_METHOD("step", "density_source",
                                  "res_x", "res_y", "res_z", "dt",
                                  "dissipation", "pressure_iters",
                                  "density_add", "reset"),
                         &GNNativeFluidVol::step);
    ClassDB::bind_method(D_METHOD("clear_state"), &GNNativeFluidVol::clear_state);
}

void GNNativeFluidVol::clear_state() {
    _velocity = PackedFloat32Array();
    _density = PackedFloat32Array();
    _rx = _ry = _rz = 0;
}

float GNNativeFluidVol::_vel_at(int x, int y, int z, int comp) const {
    x = CLAMP(x, 0, _rx - 1);
    y = CLAMP(y, 0, _ry - 1);
    z = CLAMP(z, 0, _rz - 1);
    return _velocity.ptr()[(z * _ry * _rx + y * _rx + x) * 4 + comp];
}

float GNNativeFluidVol::_pres_at(const float *p, int x, int y, int z) const {
    x = CLAMP(x, 0, _rx - 1);
    y = CLAMP(y, 0, _ry - 1);
    z = CLAMP(z, 0, _rz - 1);
    return p[z * _ry * _rx + y * _rx + x];
}

float GNNativeFluidVol::_trilinear(const float *data, double u, double v, double w) const {
    u = CLAMP(u, 0.0, 0.9999);
    v = CLAMP(v, 0.0, 0.9999);
    w = CLAMP(w, 0.0, 0.9999);
    double fx = u * (_rx - 1), fy = v * (_ry - 1), fz = w * (_rz - 1);
    int x0 = (int)fx, y0 = (int)fy, z0 = (int)fz;
    int x1 = MIN(x0 + 1, _rx - 1), y1 = MIN(y0 + 1, _ry - 1), z1 = MIN(z0 + 1, _rz - 1);
    double dx = fx - x0, dy = fy - y0, dz = fz - z0;

    auto idx = [&](int x, int y, int z) { return z * _ry * _rx + y * _rx + x; };
    float c000 = data[idx(x0, y0, z0)], c100 = data[idx(x1, y0, z0)];
    float c010 = data[idx(x0, y1, z0)], c110 = data[idx(x1, y1, z0)];
    float c001 = data[idx(x0, y0, z1)], c101 = data[idx(x1, y0, z1)];
    float c011 = data[idx(x0, y1, z1)], c111 = data[idx(x1, y1, z1)];

    float a = c000 * (1 - dx) + c100 * dx;
    float b = c010 * (1 - dx) + c110 * dx;
    float c = c001 * (1 - dx) + c101 * dx;
    float d = c011 * (1 - dx) + c111 * dx;
    float e = a * (1 - dy) + b * dy;
    float f = c * (1 - dy) + d * dy;
    return e * (1 - dz) + f * dz;
}

Dictionary GNNativeFluidVol::step(const PackedFloat32Array &density_source,
                                   int res_x, int res_y, int res_z, double dt,
                                   double dissipation, int pressure_iters,
                                   double density_add, bool reset) {
    Dictionary result;
    int total = res_x * res_y * res_z;

    // Allocate or reset
    if (reset || _rx != res_x || _ry != res_y || _rz != res_z || _density.size() != total) {
        _rx = res_x; _ry = res_y; _rz = res_z;
        _velocity.resize(total * 4);
        float *vp = _velocity.ptrw();
        for (int i = 0; i < total * 4; ++i) vp[i] = 0.0f;
        _density.resize(total);
        float *dp = _density.ptrw();
        for (int i = 0; i < total; ++i) dp[i] = 0.0f;
    }

    // Step 1: Inject density source
    if (density_source.size() > 0) {
        float *dp = _density.ptrw();
        const float *sp = density_source.ptr();
        int n = MIN(total, (int)density_source.size());
        for (int i = 0; i < n; ++i)
            dp[i] += sp[i] * (float)(density_add * dt);
    }

    // Step 2: Advect density (semi-Lagrangian)
    {
        PackedFloat32Array adv;
        adv.resize(total);
        float *ap = adv.ptrw();
        const float *dp = _density.ptr();
        const float *vp = _velocity.ptr();

        for (int z = 0; z < _rz; ++z) {
            for (int y = 0; y < _ry; ++y) {
                for (int x = 0; x < _rx; ++x) {
                    int idx4 = (z * _ry * _rx + y * _rx + x) * 4;
                    double bx = (double)x / (double)_rx - vp[idx4] * dt;
                    double by = (double)y / (double)_ry - vp[idx4 + 1] * dt;
                    double bz = (double)z / (double)_rz - vp[idx4 + 2] * dt;
                    ap[z * _ry * _rx + y * _rx + x] = _trilinear(dp, bx, by, bz) * (float)dissipation;
                }
            }
        }
        _density = adv;
    }

    // Step 3: Compute divergence
    PackedFloat32Array divergence;
    divergence.resize(total);
    {
        float *divp = divergence.ptrw();
        for (int z = 0; z < _rz; ++z) {
            for (int y = 0; y < _ry; ++y) {
                for (int x = 0; x < _rx; ++x) {
                    float dx = _vel_at(x + 1, y, z, 0) - _vel_at(x - 1, y, z, 0);
                    float dy = _vel_at(x, y + 1, z, 1) - _vel_at(x, y - 1, z, 1);
                    float dz = _vel_at(x, y, z + 1, 2) - _vel_at(x, y, z - 1, 2);
                    divp[z * _ry * _rx + y * _rx + x] = (dx + dy + dz) * -0.5f;
                }
            }
        }
    }

    // Step 4: Jacobi pressure solve
    PackedFloat32Array pressure;
    pressure.resize(total);
    float *pp = pressure.ptrw();
    for (int i = 0; i < total; ++i) pp[i] = 0.0f;

    PackedFloat32Array pressure_b;
    pressure_b.resize(total);

    for (int iter = 0; iter < pressure_iters; ++iter) {
        float *pbp = pressure_b.ptrw();
        for (int i = 0; i < total; ++i) pbp[i] = 0.0f;
        const float *prp = pressure.ptr();
        const float *divp = divergence.ptr();

        for (int z = 0; z < _rz; ++z) {
            for (int y = 0; y < _ry; ++y) {
                for (int x = 0; x < _rx; ++x) {
                    int idx = z * _ry * _rx + y * _rx + x;
                    float sum = _pres_at(prp, x - 1, y, z) + _pres_at(prp, x + 1, y, z)
                              + _pres_at(prp, x, y - 1, z) + _pres_at(prp, x, y + 1, z)
                              + _pres_at(prp, x, y, z - 1) + _pres_at(prp, x, y, z + 1);
                    pbp[idx] = (sum + divp[idx]) / 6.0f;
                }
            }
        }
        PackedFloat32Array tmp = pressure;
        pressure = pressure_b;
        pressure_b = tmp;
    }

    // Step 5: Project (subtract pressure gradient from velocity)
    {
        float *vp = _velocity.ptrw();
        const float *prp = pressure.ptr();
        for (int z = 0; z < _rz; ++z) {
            for (int y = 0; y < _ry; ++y) {
                for (int x = 0; x < _rx; ++x) {
                    int idx4 = (z * _ry * _rx + y * _rx + x) * 4;
                    vp[idx4]     -= (_pres_at(prp, x + 1, y, z) - _pres_at(prp, x - 1, y, z)) * 0.5f;
                    vp[idx4 + 1] -= (_pres_at(prp, x, y + 1, z) - _pres_at(prp, x, y - 1, z)) * 0.5f;
                    vp[idx4 + 2] -= (_pres_at(prp, x, y, z + 1) - _pres_at(prp, x, y, z - 1)) * 0.5f;
                }
            }
        }
    }

    result["density"] = _density;
    result["velocity"] = _velocity;
    return result;
}

} // namespace godot
