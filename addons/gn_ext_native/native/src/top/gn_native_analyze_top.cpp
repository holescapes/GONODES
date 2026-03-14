#include "gn_native_analyze_top.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <algorithm>

namespace godot {

void GNNativeAnalyzeTop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "source", "mode", "kernel_size"),
                         &GNNativeAnalyzeTop::process);
}

Dictionary GNNativeAnalyzeTop::process(const Ref<Image> &source, int mode,
                                        int kernel_size) {
    Dictionary result;
    if (source.is_null()) return result;

    int w = source->get_width();
    int h = source->get_height();
    if (w == 0 || h == 0) return result;

    Ref<Image> src = source->duplicate();
    src->convert(Image::FORMAT_RGBA8);
    PackedByteArray data = src->get_data();
    const uint8_t *px = data.ptr();

    int total = w * h;
    double r_val = 0, g_val = 0, b_val = 0, a_val = 0;

    if (mode == 0) { // Min
        r_val = 1.0; g_val = 1.0; b_val = 1.0; a_val = 1.0;
        for (int i = 0; i < total; ++i) {
            double r = px[i * 4 + 0] / 255.0;
            double g = px[i * 4 + 1] / 255.0;
            double b = px[i * 4 + 2] / 255.0;
            double a = px[i * 4 + 3] / 255.0;
            if (r < r_val) r_val = r;
            if (g < g_val) g_val = g;
            if (b < b_val) b_val = b;
            if (a < a_val) a_val = a;
        }
    } else if (mode == 1) { // Max
        for (int i = 0; i < total; ++i) {
            double r = px[i * 4 + 0] / 255.0;
            double g = px[i * 4 + 1] / 255.0;
            double b = px[i * 4 + 2] / 255.0;
            double a = px[i * 4 + 3] / 255.0;
            if (r > r_val) r_val = r;
            if (g > g_val) g_val = g;
            if (b > b_val) b_val = b;
            if (a > a_val) a_val = a;
        }
    } else if (mode == 2) { // Average
        for (int i = 0; i < total; ++i) {
            r_val += px[i * 4 + 0] / 255.0;
            g_val += px[i * 4 + 1] / 255.0;
            b_val += px[i * 4 + 2] / 255.0;
            a_val += px[i * 4 + 3] / 255.0;
        }
        r_val /= total;
        g_val /= total;
        b_val /= total;
        a_val /= total;
    } else { // Sum
        for (int i = 0; i < total; ++i) {
            r_val += px[i * 4 + 0] / 255.0;
            g_val += px[i * 4 + 1] / 255.0;
            b_val += px[i * 4 + 2] / 255.0;
            a_val += px[i * 4 + 3] / 255.0;
        }
    }

    result["r"] = r_val;
    result["g"] = g_val;
    result["b"] = b_val;
    result["a"] = a_val;

    // Generate solid-color result image
    uint8_t cr = (uint8_t)CLAMP(r_val * 255.0, 0.0, 255.0);
    uint8_t cg = (uint8_t)CLAMP(g_val * 255.0, 0.0, 255.0);
    uint8_t cb = (uint8_t)CLAMP(b_val * 255.0, 0.0, 255.0);
    uint8_t ca = (uint8_t)CLAMP(a_val * 255.0, 0.0, 255.0);

    PackedByteArray out_data;
    out_data.resize(w * h * 4);
    uint8_t *od = out_data.ptrw();
    for (int i = 0; i < w * h; ++i) {
        od[i * 4 + 0] = cr;
        od[i * 4 + 1] = cg;
        od[i * 4 + 2] = cb;
        od[i * 4 + 3] = ca;
    }
    result["image"] = Image::create_from_data(w, h, false, Image::FORMAT_RGBA8, out_data);

    return result;
}

} // namespace godot
