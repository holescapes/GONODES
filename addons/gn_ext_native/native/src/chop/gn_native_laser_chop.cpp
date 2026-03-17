#include "gn_native_laser_chop.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <cmath>

namespace godot {

void GNNativeLaserChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "pattern", "num_points", "scale",
                                  "rotation", "color_r", "color_g", "color_b",
                                  "intensity", "blank_points", "angle_accum"),
                         &GNNativeLaserChop::process);
}

static void _rotate_point(double &x, double &y, double angle) {
    double cs = std::cos(angle);
    double sn = std::sin(angle);
    double nx = x * cs - y * sn;
    double ny = x * sn + y * cs;
    x = nx;
    y = ny;
}

Dictionary GNNativeLaserChop::process(int pattern, int num_points, double scale,
                                       double rotation, double color_r,
                                       double color_g, double color_b,
                                       double intensity, int blank_points,
                                       double angle_accum) {
    Dictionary out;
    int total = blank_points + num_points;
    PackedFloat32Array cx, cy, cr, cg, cb, ci;
    cx.resize(total); cy.resize(total);
    cr.resize(total); cg.resize(total);
    cb.resize(total); ci.resize(total);
    float *px = cx.ptrw(), *py = cy.ptrw();
    float *pr = cr.ptrw(), *pg = cg.ptrw();
    float *pb = cb.ptrw(), *pi = ci.ptrw();

    // Blank points at start (galvo settle)
    for (int i = 0; i < blank_points; ++i) {
        px[i] = 0.0f; py[i] = 0.0f;
        pr[i] = 0.0f; pg[i] = 0.0f;
        pb[i] = 0.0f; pi[i] = 0.0f;
    }

    for (int i = 0; i < num_points; ++i) {
        double t = (double)i / (double)num_points;
        double x = 0.0, y = 0.0;

        switch (pattern) {
            case 0: { // Circle
                double a = t * Math_TAU + angle_accum;
                x = std::cos(a) * scale;
                y = std::sin(a) * scale;
                break;
            }
            case 1: { // Line
                x = (t * 2.0 - 1.0) * scale;
                y = 0.0;
                break;
            }
            case 2: { // Square
                double p = t * 4.0;
                if (p < 1.0)      { x = (-0.5 + p) * scale * 2.0; y = -0.5 * scale * 2.0; }
                else if (p < 2.0) { x = 0.5 * scale * 2.0; y = (-0.5 + (p - 1.0)) * scale * 2.0; }
                else if (p < 3.0) { x = (0.5 - (p - 2.0)) * scale * 2.0; y = 0.5 * scale * 2.0; }
                else              { x = -0.5 * scale * 2.0; y = (0.5 - (p - 3.0)) * scale * 2.0; }
                break;
            }
            case 3: { // Spiral
                double a = t * Math_TAU * 3.0 + angle_accum;
                double r = t * scale;
                x = std::cos(a) * r;
                y = std::sin(a) * r;
                break;
            }
            case 4: { // ILDA Test pattern
                double a = t * Math_TAU + angle_accum;
                double r = scale * (0.5 + 0.5 * std::sin(a * 5.0));
                x = std::cos(a) * r;
                y = std::sin(a) * r;
                break;
            }
        }

        _rotate_point(x, y, rotation);
        int idx = blank_points + i;
        px[idx] = (float)x;
        py[idx] = (float)y;
        pr[idx] = (float)color_r;
        pg[idx] = (float)color_g;
        pb[idx] = (float)color_b;
        pi[idx] = (float)intensity;
    }

    out["x"] = cx;
    out["y"] = cy;
    out["r"] = cr;
    out["g"] = cg;
    out["b"] = cb;
    out["i"] = ci;
    return out;
}

} // namespace godot
