#include "gn_native_noise.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/color.hpp>
#include <cmath>

using namespace godot;

void GNNativeNoise::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "width", "height", "type",
                                  "scale", "offset_x", "offset_y",
                                  "octaves", "persistence", "seed", "monochrome"),
                         &GNNativeNoise::process);

    BIND_ENUM_CONSTANT(NOISE_VALUE);
    BIND_ENUM_CONSTANT(NOISE_WHITE);
}

Ref<Image> GNNativeNoise::process(int p_width, int p_height, int p_type,
                                  double p_scale, double p_offset_x, double p_offset_y,
                                  int p_octaves, double p_persistence,
                                  int p_seed, bool p_monochrome) const {
    p_width = MAX(p_width, 1);
    p_height = MAX(p_height, 1);

    Ref<Image> img = Image::create_empty(p_width, p_height, false, Image::FORMAT_RGBA8);

    if (p_type == NOISE_WHITE) {
        _generate_white_noise(img, p_width, p_height, p_monochrome, static_cast<uint64_t>(p_seed));
    } else {
        _generate_value_noise(img, p_width, p_height, p_scale, p_offset_x, p_offset_y,
                              p_octaves, p_persistence, p_seed, p_monochrome);
    }

    return img;
}

// ---------------------------------------------------------------------------
// White noise
// ---------------------------------------------------------------------------

void GNNativeNoise::_generate_white_noise(const Ref<Image> &p_img, int p_w, int p_h,
                                           bool p_mono, uint64_t p_seed) const {
    // Simple xorshift64 RNG — fast, deterministic, no dependencies
    uint64_t state = p_seed ^ 0x5DEECE66DULL;
    if (state == 0) state = 1;

    auto next_float = [&]() -> double {
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        return static_cast<double>(state & 0xFFFFFFFF) / 4294967295.0;
    };

    for (int y = 0; y < p_h; ++y) {
        for (int x = 0; x < p_w; ++x) {
            if (p_mono) {
                double v = next_float();
                p_img->set_pixel(x, y, Color(v, v, v, 1.0));
            } else {
                double r = next_float();
                double g = next_float();
                double b = next_float();
                p_img->set_pixel(x, y, Color(r, g, b, 1.0));
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Value noise with fractal octaves
// ---------------------------------------------------------------------------

void GNNativeNoise::_generate_value_noise(const Ref<Image> &p_img, int p_w, int p_h,
                                           double p_scale, double p_off_x, double p_off_y,
                                           int p_octaves, double p_persistence,
                                           int p_seed, bool p_mono) const {
    double freq = p_scale / static_cast<double>(MAX(p_w, 1));

    for (int y = 0; y < p_h; ++y) {
        for (int x = 0; x < p_w; ++x) {
            double nx = (static_cast<double>(x) + p_off_x * p_w) * freq;
            double ny = (static_cast<double>(y) + p_off_y * p_h) * freq;

            double r = _fractal_noise_2d(nx, ny, p_seed, p_octaves, p_persistence) * 0.5 + 0.5;
            r = CLAMP(r, 0.0, 1.0);

            if (p_mono) {
                p_img->set_pixel(x, y, Color(r, r, r, 1.0));
            } else {
                double g = _fractal_noise_2d(nx, ny, p_seed + 1000, p_octaves, p_persistence) * 0.5 + 0.5;
                double b = _fractal_noise_2d(nx, ny, p_seed + 2000, p_octaves, p_persistence) * 0.5 + 0.5;
                g = CLAMP(g, 0.0, 1.0);
                b = CLAMP(b, 0.0, 1.0);
                p_img->set_pixel(x, y, Color(r, g, b, 1.0));
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Hash-based 2D noise primitives
// ---------------------------------------------------------------------------

double GNNativeNoise::_hash_noise_2d(double x, double y, int seed) {
    // Integer lattice hash via bit mixing
    int ix = static_cast<int>(std::floor(x));
    int iy = static_cast<int>(std::floor(y));
    int h = ix * 374761393 + iy * 668265263 + seed;
    h = (h ^ (h >> 13)) * 1274126177;
    h = h ^ (h >> 16);
    return static_cast<double>(h & 0x7FFFFFFF) / 2147483647.0;
}

double GNNativeNoise::_lerp(double a, double b, double t) {
    return a + (b - a) * t;
}

double GNNativeNoise::_smooth(double t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0); // Perlin improved smoothstep
}

double GNNativeNoise::_value_noise_2d(double x, double y, int seed) {
    double ix = std::floor(x);
    double iy = std::floor(y);
    double fx = x - ix;
    double fy = y - iy;

    double sx = _smooth(fx);
    double sy = _smooth(fy);

    double n00 = _hash_noise_2d(ix, iy, seed);
    double n10 = _hash_noise_2d(ix + 1, iy, seed);
    double n01 = _hash_noise_2d(ix, iy + 1, seed);
    double n11 = _hash_noise_2d(ix + 1, iy + 1, seed);

    double nx0 = _lerp(n00, n10, sx);
    double nx1 = _lerp(n01, n11, sx);
    return _lerp(nx0, nx1, sy) * 2.0 - 1.0; // remap 0..1 → -1..1
}

double GNNativeNoise::_fractal_noise_2d(double x, double y, int seed,
                                         int octaves, double persistence) {
    double total = 0.0;
    double amplitude = 1.0;
    double frequency = 1.0;
    double max_val = 0.0;

    for (int i = 0; i < octaves; ++i) {
        total += _value_noise_2d(x * frequency, y * frequency, seed + i * 31) * amplitude;
        max_val += amplitude;
        amplitude *= persistence;
        frequency *= 2.0;
    }

    return (max_val > 0.0) ? total / max_val : 0.0;
}
