#include "gn_native_blur.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/color.hpp>

using namespace godot;

void GNNativeBlur::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "image", "radius", "passes"), &GNNativeBlur::process);
}

Ref<Image> GNNativeBlur::process(const Ref<Image> &p_image, int p_radius, int p_passes) const {
    if (p_image.is_null()) {
        return Ref<Image>();
    }

    int w = p_image->get_width();
    int h = p_image->get_height();
    if (w == 0 || h == 0) {
        return p_image->duplicate();
    }

    p_radius = CLAMP(p_radius, 1, 64);
    p_passes = CLAMP(p_passes, 1, 4);

    Ref<Image> img = p_image->duplicate();
    for (int pass = 0; pass < p_passes; ++pass) {
        img = _box_blur(img, w, h, p_radius);
    }
    return img;
}

Ref<Image> GNNativeBlur::_box_blur(const Ref<Image> &p_src, int p_width, int p_height, int p_radius) const {
    Ref<Image> temp = Image::create_empty(p_width, p_height, false, p_src->get_format());
    Ref<Image> dst = Image::create_empty(p_width, p_height, false, p_src->get_format());

    double kernel_size = static_cast<double>(2 * p_radius + 1);

    // --- Horizontal pass: p_src → temp ---
    for (int y = 0; y < p_height; ++y) {
        double r_sum = 0.0, g_sum = 0.0, b_sum = 0.0, a_sum = 0.0;

        // Seed the accumulator
        for (int kx = -p_radius; kx <= p_radius; ++kx) {
            int sx = CLAMP(kx, 0, p_width - 1);
            Color p = p_src->get_pixel(sx, y);
            r_sum += p.r; g_sum += p.g; b_sum += p.b; a_sum += p.a;
        }
        temp->set_pixel(0, y, Color(r_sum / kernel_size, g_sum / kernel_size,
                                     b_sum / kernel_size, a_sum / kernel_size));

        // Slide the window
        for (int x = 1; x < p_width; ++x) {
            int add_x = CLAMP(x + p_radius, 0, p_width - 1);
            int rem_x = CLAMP(x - p_radius - 1, 0, p_width - 1);
            Color pa = p_src->get_pixel(add_x, y);
            Color pr = p_src->get_pixel(rem_x, y);
            r_sum += pa.r - pr.r;
            g_sum += pa.g - pr.g;
            b_sum += pa.b - pr.b;
            a_sum += pa.a - pr.a;
            temp->set_pixel(x, y, Color(r_sum / kernel_size, g_sum / kernel_size,
                                         b_sum / kernel_size, a_sum / kernel_size));
        }
    }

    // --- Vertical pass: temp → dst ---
    for (int x = 0; x < p_width; ++x) {
        double r_sum = 0.0, g_sum = 0.0, b_sum = 0.0, a_sum = 0.0;

        for (int ky = -p_radius; ky <= p_radius; ++ky) {
            int sy = CLAMP(ky, 0, p_height - 1);
            Color p = temp->get_pixel(x, sy);
            r_sum += p.r; g_sum += p.g; b_sum += p.b; a_sum += p.a;
        }
        dst->set_pixel(x, 0, Color(r_sum / kernel_size, g_sum / kernel_size,
                                     b_sum / kernel_size, a_sum / kernel_size));

        for (int y = 1; y < p_height; ++y) {
            int add_y = CLAMP(y + p_radius, 0, p_height - 1);
            int rem_y = CLAMP(y - p_radius - 1, 0, p_height - 1);
            Color pa = temp->get_pixel(x, add_y);
            Color pr = temp->get_pixel(x, rem_y);
            r_sum += pa.r - pr.r;
            g_sum += pa.g - pr.g;
            b_sum += pa.b - pr.b;
            a_sum += pa.a - pr.a;
            dst->set_pixel(x, y, Color(r_sum / kernel_size, g_sum / kernel_size,
                                         b_sum / kernel_size, a_sum / kernel_size));
        }
    }

    return dst;
}
