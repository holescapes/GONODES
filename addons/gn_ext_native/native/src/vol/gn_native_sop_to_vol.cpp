#include "gn_native_sop_to_vol.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeSopToVol::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions",
                                  "res_x", "res_y", "res_z",
                                  "radius", "strength", "padding"),
                         &GNNativeSopToVol::process);
}

Dictionary GNNativeSopToVol::process(const PackedVector3Array &positions,
                                      int res_x, int res_y, int res_z,
                                      double radius, double strength,
                                      double padding) {
    Dictionary result;
    int pt_count = positions.size();
    if (pt_count == 0) {
        result["field"] = PackedFloat32Array();
        return result;
    }

    const Vector3 *pts = positions.ptr();

    // Compute bounds
    Vector3 bmin(1e30, 1e30, 1e30), bmax(-1e30, -1e30, -1e30);
    for (int i = 0; i < pt_count; ++i) {
        Vector3 p = pts[i];
        if (p.x < bmin.x) bmin.x = p.x;
        if (p.y < bmin.y) bmin.y = p.y;
        if (p.z < bmin.z) bmin.z = p.z;
        if (p.x > bmax.x) bmax.x = p.x;
        if (p.y > bmax.y) bmax.y = p.y;
        if (p.z > bmax.z) bmax.z = p.z;
    }
    bmin -= Vector3(padding, padding, padding);
    bmax += Vector3(padding, padding, padding);
    Vector3 bsize = bmax - bmin;
    if (bsize.x < 0.001) bsize.x = 1.0;
    if (bsize.y < 0.001) bsize.y = 1.0;
    if (bsize.z < 0.001) bsize.z = 1.0;

    int total = res_x * res_y * res_z;
    PackedFloat32Array field;
    field.resize(total);
    float *f = field.ptrw();
    for (int i = 0; i < total; ++i) f[i] = 0.0f;

    Vector3 inv_size(1.0 / bsize.x, 1.0 / bsize.y, 1.0 / bsize.z);
    int rvx = (int)std::ceil(radius * inv_size.x * res_x);
    int rvy = (int)std::ceil(radius * inv_size.y * res_y);
    int rvz = (int)std::ceil(radius * inv_size.z * res_z);

    for (int pi = 0; pi < pt_count; ++pi) {
        Vector3 pt = pts[pi];
        double gfx = (pt.x - bmin.x) * inv_size.x * res_x;
        double gfy = (pt.y - bmin.y) * inv_size.y * res_y;
        double gfz = (pt.z - bmin.z) * inv_size.z * res_z;
        int gcx = (int)gfx, gcy = (int)gfy, gcz = (int)gfz;

        for (int dz = -rvz; dz <= rvz; ++dz) {
            int vz = gcz + dz;
            if (vz < 0 || vz >= res_z) continue;
            for (int dy = -rvy; dy <= rvy; ++dy) {
                int vy = gcy + dy;
                if (vy < 0 || vy >= res_y) continue;
                for (int dx = -rvx; dx <= rvx; ++dx) {
                    int vx = gcx + dx;
                    if (vx < 0 || vx >= res_x) continue;
                    // World-space distance
                    double wx = bmin.x + ((double)vx + 0.5) / (double)res_x * bsize.x;
                    double wy = bmin.y + ((double)vy + 0.5) / (double)res_y * bsize.y;
                    double wz = bmin.z + ((double)vz + 0.5) / (double)res_z * bsize.z;
                    double dist = std::sqrt((pt.x - wx) * (pt.x - wx) +
                                            (pt.y - wy) * (pt.y - wy) +
                                            (pt.z - wz) * (pt.z - wz));
                    if (dist < radius) {
                        double falloff = 1.0 - (dist / radius);
                        f[vz * res_y * res_x + vy * res_x + vx] += (float)(strength * falloff);
                    }
                }
            }
        }
    }

    result["field"] = field;
    result["bmin_x"] = bmin.x;
    result["bmin_y"] = bmin.y;
    result["bmin_z"] = bmin.z;
    result["bsize_x"] = bsize.x;
    result["bsize_y"] = bsize.y;
    result["bsize_z"] = bsize.z;
    return result;
}

} // namespace godot
