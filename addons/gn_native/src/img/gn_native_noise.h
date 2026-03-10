#ifndef GN_NATIVE_NOISE_H
#define GN_NATIVE_NOISE_H

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

/// Native procedural noise image generator.
/// Supports white noise and value noise (via built-in permutation hash).
class GNNativeNoise : public RefCounted {
    GDCLASS(GNNativeNoise, RefCounted)

protected:
    static void _bind_methods();

public:
    enum NoiseType {
        NOISE_VALUE = 0,
        NOISE_WHITE = 1,
    };

    /// Generates a noise image.
    /// @param p_width       Image width.
    /// @param p_height      Image height.
    /// @param p_type        0 = value/simplex noise, 1 = white noise.
    /// @param p_scale       Spatial frequency (value noise only).
    /// @param p_offset_x    Horizontal offset.
    /// @param p_offset_y    Vertical offset.
    /// @param p_octaves     Fractal octave count (value noise).
    /// @param p_persistence Amplitude decay per octave.
    /// @param p_seed        Random seed.
    /// @param p_monochrome  Grayscale (true) or RGB (false).
    Ref<Image> process(int p_width, int p_height, int p_type,
                       double p_scale, double p_offset_x, double p_offset_y,
                       int p_octaves, double p_persistence,
                       int p_seed, bool p_monochrome) const;

private:
    void _generate_white_noise(const Ref<Image> &p_img, int p_w, int p_h,
                               bool p_mono, uint64_t p_seed) const;
    void _generate_value_noise(const Ref<Image> &p_img, int p_w, int p_h,
                               double p_scale, double p_off_x, double p_off_y,
                               int p_octaves, double p_persistence,
                               int p_seed, bool p_mono) const;

    // Simple hash-based noise (no external deps)
    static double _hash_noise_2d(double x, double y, int seed);
    static double _lerp(double a, double b, double t);
    static double _smooth(double t);
    static double _value_noise_2d(double x, double y, int seed);
    static double _fractal_noise_2d(double x, double y, int seed,
                                    int octaves, double persistence);
};

} // namespace godot

VARIANT_ENUM_CAST(GNNativeNoise::NoiseType);

#endif // GN_NATIVE_NOISE_H
