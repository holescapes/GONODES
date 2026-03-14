#include "gn_native_checkerboard_img.h"

#include <godot_cpp/core/class_db.hpp>


namespace godot {

void GNNativeCheckerboardImg::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "width", "height", "cells_x",
                                  "cells_y", "color_a", "color_b", "softness"),
                         &GNNativeCheckerboardImg::process);
}

Ref<Image> GNNativeCheckerboardImg::process(int width, int height,
                                             int cells_x, int cells_y,
                                             const Color &color_a,
                                             const Color &color_b,
                                             double softness) {
    if (width < 1) width = 1;
    if (height < 1) height = 1;
    if (cells_x < 1) cells_x = 1;
    if (cells_y < 1) cells_y = 1;

    Ref<Image> img = Image::create_empty(width, height, false, Image::FORMAT_RGBA8);

    float cw = (float)width / (float)cells_x;
    float ch = (float)height / (float)cells_y;
    float soft = (float)softness;

    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            int cx = (int)((float)x / cw);
            int cy = (int)((float)y / ch);
            bool is_a = ((cx + cy) % 2 == 0);

            if (soft > 0.001f) {
                // Soft-edge blending
                float fx = fmodf((float)x, cw) / cw; // 0..1 within cell
                float fy = fmodf((float)y, ch) / ch;
                float dx = MIN(fx, 1.0f - fx) * 2.0f; // Distance from edge (0..1)
                float dy = MIN(fy, 1.0f - fy) * 2.0f;
                float d = MIN(dx, dy);
                float blend = CLAMP(d / soft, 0.0f, 1.0f);

                Color base = is_a ? color_a : color_b;
                Color other = is_a ? color_b : color_a;
                img->set_pixel(x, y, base.lerp(other, 1.0f - blend));
            } else {
                img->set_pixel(x, y, is_a ? color_a : color_b);
            }
        }
    }

    return img;
}

} // namespace godot
