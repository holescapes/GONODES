#include "gn_native_pixel_sort.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/color.hpp>
#include <vector>
#include <cmath>

using namespace godot;

void GNNativePixelSort::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "image", "direction", "sort_mode",
                                  "threshold_low", "threshold_high", "reverse"),
                         &GNNativePixelSort::process);

    BIND_ENUM_CONSTANT(SORT_HORIZONTAL);
    BIND_ENUM_CONSTANT(SORT_VERTICAL);
    BIND_ENUM_CONSTANT(MODE_BRIGHTNESS);
    BIND_ENUM_CONSTANT(MODE_HUE);
    BIND_ENUM_CONSTANT(MODE_SATURATION);
    BIND_ENUM_CONSTANT(MODE_RED);
    BIND_ENUM_CONSTANT(MODE_GREEN);
    BIND_ENUM_CONSTANT(MODE_BLUE);
}

Ref<Image> GNNativePixelSort::process(const Ref<Image> &p_image, int p_direction,
                                       int p_sort_mode, double p_threshold_low,
                                       double p_threshold_high, bool p_reverse) const {
    if (p_image.is_null()) {
        return Ref<Image>();
    }

    Ref<Image> img = p_image->duplicate();
    int w = img->get_width();
    int h = img->get_height();
    if (w == 0 || h == 0) {
        return img;
    }

    if (p_direction == SORT_HORIZONTAL) {
        // Sort each row
        std::vector<Color> pixels(w);
        std::vector<double> keys(w);

        for (int y = 0; y < h; ++y) {
            // Gather row
            for (int x = 0; x < w; ++x) {
                pixels[x] = img->get_pixel(x, y);
                keys[x] = _get_sort_key(pixels[x], p_sort_mode);
            }

            // Find and sort spans
            int span_start = -1;
            for (int x = 0; x < w; ++x) {
                double b = _get_brightness(pixels[x]);
                bool in_range = b >= p_threshold_low && b <= p_threshold_high;

                if (in_range && span_start == -1) {
                    span_start = x;
                } else if ((!in_range || x == w - 1) && span_start != -1) {
                    int span_end = in_range ? x + 1 : x;
                    _sort_span(pixels.data(), keys.data(), span_start, span_end, p_reverse);
                    span_start = -1;
                }
            }

            // Write back
            for (int x = 0; x < w; ++x) {
                img->set_pixel(x, y, pixels[x]);
            }
        }
    } else {
        // Sort each column
        std::vector<Color> pixels(h);
        std::vector<double> keys(h);

        for (int x = 0; x < w; ++x) {
            // Gather column
            for (int y = 0; y < h; ++y) {
                pixels[y] = img->get_pixel(x, y);
                keys[y] = _get_sort_key(pixels[y], p_sort_mode);
            }

            int span_start = -1;
            for (int y = 0; y < h; ++y) {
                double b = _get_brightness(pixels[y]);
                bool in_range = b >= p_threshold_low && b <= p_threshold_high;

                if (in_range && span_start == -1) {
                    span_start = y;
                } else if ((!in_range || y == h - 1) && span_start != -1) {
                    int span_end = in_range ? y + 1 : y;
                    _sort_span(pixels.data(), keys.data(), span_start, span_end, p_reverse);
                    span_start = -1;
                }
            }

            for (int y = 0; y < h; ++y) {
                img->set_pixel(x, y, pixels[y]);
            }
        }
    }

    return img;
}

double GNNativePixelSort::_get_brightness(const Color &c) {
    return c.r * 0.299 + c.g * 0.587 + c.b * 0.114;
}

double GNNativePixelSort::_get_sort_key(const Color &c, int mode) {
    switch (mode) {
        case MODE_HUE:        return c.get_h();
        case MODE_SATURATION: return c.get_s();
        case MODE_RED:        return c.r;
        case MODE_GREEN:      return c.g;
        case MODE_BLUE:       return c.b;
        default:              return c.r * 0.299 + c.g * 0.587 + c.b * 0.114;
    }
}

void GNNativePixelSort::_sort_span(Color *pixels, double *keys,
                                    int start, int end, bool reverse) {
    if (end - start <= 1) return;

    // Insertion sort — efficient for typical short pixel spans
    for (int i = start + 1; i < end; ++i) {
        double key_i = keys[i];
        Color pix_i = pixels[i];
        int j = i - 1;
        if (reverse) {
            while (j >= start && keys[j] < key_i) {
                keys[j + 1] = keys[j];
                pixels[j + 1] = pixels[j];
                --j;
            }
        } else {
            while (j >= start && keys[j] > key_i) {
                keys[j + 1] = keys[j];
                pixels[j + 1] = pixels[j];
                --j;
            }
        }
        keys[j + 1] = key_i;
        pixels[j + 1] = pix_i;
    }
}
