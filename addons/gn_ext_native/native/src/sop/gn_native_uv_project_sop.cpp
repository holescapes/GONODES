#include "gn_native_uv_project_sop.h"

#include <godot_cpp/core/class_db.hpp>


namespace godot {

void GNNativeUvProjectSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "verts", "mode", "axis",
                                  "scale_u", "scale_v"),
                         &GNNativeUvProjectSop::process);
}

PackedVector2Array GNNativeUvProjectSop::process(const PackedVector3Array &verts,
                                                  int mode, int axis,
                                                  double scale_u, double scale_v) {
    int n = verts.size();
    PackedVector2Array out;
    out.resize(n);
    Vector2 *op = out.ptrw();
    const Vector3 *vp = verts.ptr();

    float su = (float)scale_u;
    float sv = (float)scale_v;
    if (fabsf(su) < 1e-10f) su = 1.0f;
    if (fabsf(sv) < 1e-10f) sv = 1.0f;

    for (int i = 0; i < n; ++i) {
        Vector3 p = vp[i];
        float u = 0.0f, v = 0.0f;

        if (mode == 0) {
            // Planar
            switch (axis) {
                case 0: u = p.z / su; v = p.y / sv; break; // X axis → z/y
                case 1: u = p.x / su; v = p.z / sv; break; // Y axis → x/z
                default: u = p.x / su; v = p.y / sv; break; // Z axis → x/y
            }
        } else if (mode == 1) {
            // Cylindrical
            float ax0 = 0, ax1 = 0, ax_h = 0;
            switch (axis) {
                case 0: ax0 = p.z; ax1 = p.y; ax_h = p.x; break;
                case 1: ax0 = p.x; ax1 = p.z; ax_h = p.y; break;
                default: ax0 = p.x; ax1 = p.y; ax_h = p.z; break;
            }
            u = (atan2f(ax1, ax0) / (float)Math_PI + 1.0f) * 0.5f * su;
            v = ax_h / sv;
        } else {
            // Spherical
            float len = p.length();
            if (len < 1e-10f) {
                u = v = 0.5f;
            } else {
                Vector3 pn = p / len;
                float ax0 = 0, ax1 = 0, ax_h = 0;
                switch (axis) {
                    case 0: ax0 = pn.z; ax1 = pn.y; ax_h = pn.x; break;
                    case 1: ax0 = pn.x; ax1 = pn.z; ax_h = pn.y; break;
                    default: ax0 = pn.x; ax1 = pn.y; ax_h = pn.z; break;
                }
                u = (atan2f(ax1, ax0) / (float)Math_PI + 1.0f) * 0.5f * su;
                v = (asinf(CLAMP(ax_h, -1.0f, 1.0f)) / (float)Math_PI + 0.5f) * sv;
            }
        }

        op[i] = Vector2(u, v);
    }

    return out;
}

} // namespace godot
