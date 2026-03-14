#include "gn_native_top_to_chop.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

void GNNativeTopToChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "img", "mode",
                                  "want_r", "want_g", "want_b", "want_a"),
                         &GNNativeTopToChop::process);
}

Dictionary GNNativeTopToChop::process(const Ref<Image> &img, int mode,
                                       bool want_r, bool want_g,
                                       bool want_b, bool want_a) {
    Dictionary result;
    if (img.is_null()) return result;

    int w = img->get_width();
    int h = img->get_height();
    if (w == 0 || h == 0) return result;

    if (mode == 0) {
        // Average
        double sr = 0, sg = 0, sb = 0, sa = 0;
        double total = (double)(w * h);
        for (int y = 0; y < h; ++y) {
            for (int x = 0; x < w; ++x) {
                Color c = img->get_pixel(x, y);
                sr += c.r; sg += c.g; sb += c.b; sa += c.a;
            }
        }
        PackedFloat32Array r_arr, g_arr, b_arr, a_arr;
        r_arr.resize(1); g_arr.resize(1); b_arr.resize(1); a_arr.resize(1);
        r_arr[0] = (float)(sr / total);
        g_arr[0] = (float)(sg / total);
        b_arr[0] = (float)(sb / total);
        a_arr[0] = (float)(sa / total);
        if (want_r) result["r"] = r_arr;
        if (want_g) result["g"] = g_arr;
        if (want_b) result["b"] = b_arr;
        if (want_a) result["a"] = a_arr;
        result["length"] = 1;

    } else if (mode == 1) {
        // Center pixel
        int cx = w / 2, cy = h / 2;
        Color c = img->get_pixel(cx, cy);
        PackedFloat32Array r_arr, g_arr, b_arr, a_arr;
        r_arr.resize(1); g_arr.resize(1); b_arr.resize(1); a_arr.resize(1);
        r_arr[0] = c.r; g_arr[0] = c.g; b_arr[0] = c.b; a_arr[0] = c.a;
        if (want_r) result["r"] = r_arr;
        if (want_g) result["g"] = g_arr;
        if (want_b) result["b"] = b_arr;
        if (want_a) result["a"] = a_arr;
        result["length"] = 1;

    } else if (mode == 2) {
        // Row average
        PackedFloat32Array rr, rg, rb, ra;
        rr.resize(h); rg.resize(h); rb.resize(h); ra.resize(h);
        float *rrp = rr.ptrw(), *rgp = rg.ptrw(), *rbp = rb.ptrw(), *rap = ra.ptrw();
        float inv_w = 1.0f / (float)w;
        for (int y = 0; y < h; ++y) {
            float sr = 0, sg = 0, sb = 0, sa = 0;
            for (int x = 0; x < w; ++x) {
                Color c = img->get_pixel(x, y);
                sr += c.r; sg += c.g; sb += c.b; sa += c.a;
            }
            rrp[y] = sr * inv_w; rgp[y] = sg * inv_w;
            rbp[y] = sb * inv_w; rap[y] = sa * inv_w;
        }
        if (want_r) result["r"] = rr;
        if (want_g) result["g"] = rg;
        if (want_b) result["b"] = rb;
        if (want_a) result["a"] = ra;
        result["length"] = h;

    } else {
        // Column average
        PackedFloat32Array rr, rg, rb, ra;
        rr.resize(w); rg.resize(w); rb.resize(w); ra.resize(w);
        float *rrp = rr.ptrw(), *rgp = rg.ptrw(), *rbp = rb.ptrw(), *rap = ra.ptrw();
        float inv_h = 1.0f / (float)h;
        for (int x = 0; x < w; ++x) {
            float sr = 0, sg = 0, sb = 0, sa = 0;
            for (int y = 0; y < h; ++y) {
                Color c = img->get_pixel(x, y);
                sr += c.r; sg += c.g; sb += c.b; sa += c.a;
            }
            rrp[x] = sr * inv_h; rgp[x] = sg * inv_h;
            rbp[x] = sb * inv_h; rap[x] = sa * inv_h;
        }
        if (want_r) result["r"] = rr;
        if (want_g) result["g"] = rg;
        if (want_b) result["b"] = rb;
        if (want_a) result["a"] = ra;
        result["length"] = w;
    }

    return result;
}

} // namespace godot
