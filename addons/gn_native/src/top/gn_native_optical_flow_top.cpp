#include "gn_native_optical_flow_top.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <vector>

namespace godot {

void GNNativeOpticalFlowTop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "prev_frame", "curr_frame",
                                  "iterations", "lambda", "scale"),
                         &GNNativeOpticalFlowTop::process);
}

static float _luminance(uint8_t r, uint8_t g, uint8_t b) {
    return 0.299f * r + 0.587f * g + 0.114f * b;
}

Ref<Image> GNNativeOpticalFlowTop::process(const Ref<Image> &prev_frame,
                                            const Ref<Image> &curr_frame,
                                            int iterations, double lambda,
                                            double scale) {
    if (prev_frame.is_null() || curr_frame.is_null()) return Ref<Image>();

    int w = prev_frame->get_width();
    int h = prev_frame->get_height();
    if (w < 2 || h < 2) return Ref<Image>();
    if (curr_frame->get_width() != w || curr_frame->get_height() != h) return Ref<Image>();

    // Convert to grayscale luminance
    PackedByteArray prev_data = prev_frame->get_data();
    PackedByteArray curr_data = curr_frame->get_data();

    // Work at format RGBA8
    Ref<Image> prev_rgba = prev_frame->duplicate();
    prev_rgba->convert(Image::FORMAT_RGBA8);
    Ref<Image> curr_rgba = curr_frame->duplicate();
    curr_rgba->convert(Image::FORMAT_RGBA8);

    PackedByteArray pdata = prev_rgba->get_data();
    PackedByteArray cdata = curr_rgba->get_data();
    const uint8_t *pp = pdata.ptr();
    const uint8_t *cp = cdata.ptr();

    std::vector<float> prev_lum(w * h);
    std::vector<float> curr_lum(w * h);
    for (int i = 0; i < w * h; ++i) {
        prev_lum[i] = _luminance(pp[i * 4], pp[i * 4 + 1], pp[i * 4 + 2]) / 255.0f;
        curr_lum[i] = _luminance(cp[i * 4], cp[i * 4 + 1], cp[i * 4 + 2]) / 255.0f;
    }

    // Horn-Schunck optical flow
    std::vector<float> u(w * h, 0.0f);
    std::vector<float> v(w * h, 0.0f);
    double alpha2 = lambda * lambda;

    for (int iter = 0; iter < iterations; ++iter) {
        std::vector<float> u_avg(w * h);
        std::vector<float> v_avg(w * h);

        for (int y = 0; y < h; ++y) {
            for (int x = 0; x < w; ++x) {
                int idx = y * w + x;
                float sum_u = 0, sum_v = 0;
                int cnt = 0;
                if (x > 0) { sum_u += u[idx - 1]; sum_v += v[idx - 1]; ++cnt; }
                if (x < w - 1) { sum_u += u[idx + 1]; sum_v += v[idx + 1]; ++cnt; }
                if (y > 0) { sum_u += u[idx - w]; sum_v += v[idx - w]; ++cnt; }
                if (y < h - 1) { sum_u += u[idx + w]; sum_v += v[idx + w]; ++cnt; }
                u_avg[idx] = cnt > 0 ? sum_u / cnt : u[idx];
                v_avg[idx] = cnt > 0 ? sum_v / cnt : v[idx];
            }
        }

        for (int y = 1; y < h - 1; ++y) {
            for (int x = 1; x < w - 1; ++x) {
                int idx = y * w + x;
                float Ix = (curr_lum[idx + 1] - curr_lum[idx - 1]) * 0.5f;
                float Iy = (curr_lum[idx + w] - curr_lum[idx - w]) * 0.5f;
                float It = curr_lum[idx] - prev_lum[idx];

                float denom = alpha2 + Ix * Ix + Iy * Iy;
                float p = (Ix * u_avg[idx] + Iy * v_avg[idx] + It) / denom;

                u[idx] = u_avg[idx] - Ix * p;
                v[idx] = v_avg[idx] - Iy * p;
            }
        }
    }

    // Encode flow as RGBA8 image: R=u, G=v mapped to 0..255
    PackedByteArray out_data;
    out_data.resize(w * h * 4);
    uint8_t *od = out_data.ptrw();

    for (int i = 0; i < w * h; ++i) {
        float fu = u[i] * (float)scale * 0.5f + 0.5f;
        float fv = v[i] * (float)scale * 0.5f + 0.5f;
        od[i * 4 + 0] = (uint8_t)CLAMP(fu * 255.0f, 0.0f, 255.0f);
        od[i * 4 + 1] = (uint8_t)CLAMP(fv * 255.0f, 0.0f, 255.0f);
        od[i * 4 + 2] = 0;
        od[i * 4 + 3] = 255;
    }

    return Image::create_from_data(w, h, false, Image::FORMAT_RGBA8, out_data);
}

} // namespace godot
