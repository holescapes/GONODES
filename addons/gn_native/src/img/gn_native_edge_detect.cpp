#include "gn_native_edge_detect.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/color.hpp>
#include <cmath>
#include <vector>

using namespace godot;

void GNNativeEdgeDetect::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "image", "kernel", "strength", "invert", "color_edges"),
                         &GNNativeEdgeDetect::process);
}

Ref<Image> GNNativeEdgeDetect::process(const Ref<Image> &p_image, int kernel,
                                        double strength, bool invert, bool color_edges) const {
    if (p_image.is_null()) return Ref<Image>();

    int w = p_image->get_width();
    int h = p_image->get_height();
    if (w < 3 || h < 3) return p_image->duplicate();

    // Precompute luminance buffer
    std::vector<float> lum(w * h);
    for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
            Color p = p_image->get_pixel(x, y);
            lum[y * w + x] = p.r * 0.299f + p.g * 0.587f + p.b * 0.114f;
        }
    }

    // Kernel weights
    float kx[9], ky[9];
    if (kernel == 1) { // Prewitt
        float _kx[] = {-1,0,1, -1,0,1, -1,0,1};
        float _ky[] = {-1,-1,-1, 0,0,0, 1,1,1};
        memcpy(kx, _kx, sizeof(kx));
        memcpy(ky, _ky, sizeof(ky));
    } else { // Sobel
        float _kx[] = {-1,0,1, -2,0,2, -1,0,1};
        float _ky[] = {-1,-2,-1, 0,0,0, 1,2,1};
        memcpy(kx, _kx, sizeof(kx));
        memcpy(ky, _ky, sizeof(ky));
    }

    Ref<Image> img = Image::create_empty(w, h, false, Image::FORMAT_RGBA8);

    for (int y = 1; y < h - 1; ++y) {
        for (int x = 1; x < w - 1; ++x) {
            float gx = 0.0f, gy = 0.0f;
            int ki = 0;
            for (int ky_off = -1; ky_off <= 1; ++ky_off) {
                for (int kx_off = -1; kx_off <= 1; ++kx_off) {
                    float l = lum[(y + ky_off) * w + (x + kx_off)];
                    gx += l * kx[ki];
                    gy += l * ky[ki];
                    ++ki;
                }
            }

            float mag = std::sqrt(gx * gx + gy * gy) * (float)strength;

            if (color_edges) {
                float r = std::fmin(std::fabs(gx) * (float)strength, 1.0f);
                float g = std::fmin(std::fabs(gy) * (float)strength, 1.0f);
                float b = std::fmin(mag, 1.0f);
                if (invert) {
                    img->set_pixel(x, y, Color(1.0f - r, 1.0f - g, 1.0f - b, 1.0f));
                } else {
                    img->set_pixel(x, y, Color(r, g, b, 1.0f));
                }
            } else {
                mag = std::fmin(mag, 1.0f);
                if (invert) mag = 1.0f - mag;
                img->set_pixel(x, y, Color(mag, mag, mag, 1.0f));
            }
        }
    }

    // Fill border pixels
    for (int x = 0; x < w; ++x) {
        int cx = x < 1 ? 1 : (x >= w - 1 ? w - 2 : x);
        img->set_pixel(x, 0, img->get_pixel(cx, 1));
        img->set_pixel(x, h - 1, img->get_pixel(cx, h - 2));
    }
    for (int y = 0; y < h; ++y) {
        int cy = y < 1 ? 1 : (y >= h - 1 ? h - 2 : y);
        img->set_pixel(0, y, img->get_pixel(1, cy));
        img->set_pixel(w - 1, y, img->get_pixel(w - 2, cy));
    }

    return img;
}
