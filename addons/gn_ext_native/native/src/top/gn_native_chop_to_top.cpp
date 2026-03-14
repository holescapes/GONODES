#include "gn_native_chop_to_top.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>


namespace godot {

void GNNativeChopToTop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "channels", "ch_names",
                                  "mode", "width", "height", "bg", "line_color",
                                  "line_width", "min_val", "max_val"),
                         &GNNativeChopToTop::process);
}

static int val_to_y(float val, float min_v, float max_v, int h) {
    float range = max_v - min_v;
    float t = (fabsf(range) > 0.0001f) ? (val - min_v) / range : 0.5f;
    if (t < 0.0f) t = 0.0f;
    if (t > 1.0f) t = 1.0f;
    int y = h - 1 - (int)(t * (float)(h - 1));
    return CLAMP(y, 0, h - 1);
}

Ref<Image> GNNativeChopToTop::process(const Dictionary &channels,
                                       const PackedStringArray &ch_names,
                                       int mode, int w, int h,
                                       const Color &bg, const Color &line_color,
                                       double line_width,
                                       double min_val, double max_val) {
    if (w < 1) w = 1;
    if (h < 1) h = 1;
    int ch_count = ch_names.size();
    if (ch_count == 0) return Ref<Image>();

    Ref<Image> img = Image::create_empty(w, h, false, Image::FORMAT_RGBA8);
    img->fill(bg);

    float min_v = (float)min_val;
    float max_v = (float)max_val;

    if (mode == 0) {
        // Waveform
        int half_lw = MAX((int)(line_width * 0.5), 0);
        for (int ci = 0; ci < ch_count; ++ci) {
            Variant v = channels.get(ch_names[ci], Variant());
            if (v.get_type() != Variant::PACKED_FLOAT32_ARRAY) continue;
            PackedFloat32Array data = v;
            int samples = data.size();
            if (samples == 0) continue;
            const float *dp = data.ptr();

            Color col = line_color;
            if (ch_count > 1) {
                col = Color::from_hsv(fmodf(line_color.get_h() + (float)ci / (float)ch_count, 1.0f),
                                      line_color.get_s(), line_color.get_v(), line_color.a);
            }

            int prev_y = -1;
            for (int px = 0; px < w; ++px) {
                float t = w > 1 ? (float)px / (float)(w - 1) : 0.0f;
                float si = t * (float)(samples - 1);
                int si0 = CLAMP((int)si, 0, samples - 1);
                int si1 = CLAMP(si0 + 1, 0, samples - 1);
                float frac = si - (float)si0;
                float val = dp[si0] * (1.0f - frac) + dp[si1] * frac;
                int cur_y = val_to_y(val, min_v, max_v, h);

                for (int dy = -half_lw; dy <= half_lw; ++dy) {
                    int y = CLAMP(cur_y + dy, 0, h - 1);
                    img->set_pixel(px, y, col);
                }

                if (px > 0 && prev_y >= 0) {
                    int y_lo = MIN(prev_y, cur_y);
                    int y_hi = MAX(prev_y, cur_y);
                    for (int y = y_lo; y <= y_hi; ++y) {
                        img->set_pixel(px, CLAMP(y, 0, h - 1), col);
                    }
                }
                prev_y = cur_y;
            }
        }
    } else if (mode == 1) {
        // Heatmap
        int row_h = MAX(h / ch_count, 1);
        for (int ci = 0; ci < ch_count; ++ci) {
            Variant v = channels.get(ch_names[ci], Variant());
            if (v.get_type() != Variant::PACKED_FLOAT32_ARRAY) continue;
            PackedFloat32Array data = v;
            int samples = data.size();
            if (samples == 0) continue;
            const float *dp = data.ptr();
            int y_start = ci * row_h;
            int y_end = MIN(y_start + row_h, h);

            for (int px = 0; px < w; ++px) {
                int si = CLAMP((int)((float)px / (float)w * (float)samples), 0, samples - 1);
                float range = max_v - min_v;
                float t = (fabsf(range) > 0.0001f) ? (dp[si] - min_v) / range : 0.5f;
                if (t < 0.0f) t = 0.0f;
                if (t > 1.0f) t = 1.0f;
                Color col(t, 0.2f * (1.0f - fabsf(t - 0.5f) * 2.0f), 1.0f - t, 1.0f);
                for (int y = y_start; y < y_end; ++y) {
                    img->set_pixel(px, y, col);
                }
            }
        }
    } else {
        // Graph — same as waveform but fills below
        for (int ci = 0; ci < ch_count; ++ci) {
            Variant v = channels.get(ch_names[ci], Variant());
            if (v.get_type() != Variant::PACKED_FLOAT32_ARRAY) continue;
            PackedFloat32Array data = v;
            int samples = data.size();
            if (samples == 0) continue;
            const float *dp = data.ptr();

            Color col = line_color;
            if (ch_count > 1) {
                col = Color::from_hsv(fmodf(line_color.get_h() + (float)ci / (float)ch_count, 1.0f),
                                      line_color.get_s(), line_color.get_v(), line_color.a);
            }
            Color fill = Color(col.r, col.g, col.b, col.a * 0.3f);

            for (int px = 0; px < w; ++px) {
                float t = w > 1 ? (float)px / (float)(w - 1) : 0.0f;
                float si = t * (float)(samples - 1);
                int si0 = CLAMP((int)si, 0, samples - 1);
                int si1 = CLAMP(si0 + 1, 0, samples - 1);
                float frac = si - (float)si0;
                float val = dp[si0] * (1.0f - frac) + dp[si1] * frac;
                int cur_y = val_to_y(val, min_v, max_v, h);

                img->set_pixel(px, cur_y, col);
                // Fill below
                for (int y = cur_y + 1; y < h; ++y) {
                    img->set_pixel(px, y, fill);
                }
            }
        }
    }

    return img;
}

} // namespace godot
