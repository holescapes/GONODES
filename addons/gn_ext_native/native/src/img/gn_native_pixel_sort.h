#ifndef GN_NATIVE_PIXEL_SORT_H
#define GN_NATIVE_PIXEL_SORT_H

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

/// Native pixel-sorting glitch-art processor.
/// Detects threshold-gated spans along rows or columns, sorts pixels
/// by a chosen key (brightness, hue, saturation, R, G, B).
class GNNativePixelSort : public RefCounted {
    GDCLASS(GNNativePixelSort, RefCounted)

protected:
    static void _bind_methods();

public:
    enum SortDirection {
        SORT_HORIZONTAL = 0,
        SORT_VERTICAL = 1,
    };

    enum SortMode {
        MODE_BRIGHTNESS = 0,
        MODE_HUE = 1,
        MODE_SATURATION = 2,
        MODE_RED = 3,
        MODE_GREEN = 4,
        MODE_BLUE = 5,
    };

    /// Pixel-sort the image in-place and return the result.
    /// @param p_image         Source image (duplicated internally).
    /// @param p_direction     0 = horizontal, 1 = vertical.
    /// @param p_sort_mode     Sort key selector.
    /// @param p_threshold_low  Minimum brightness for span inclusion.
    /// @param p_threshold_high Maximum brightness for span inclusion.
    /// @param p_reverse       Sort descending if true.
    Ref<Image> process(const Ref<Image> &p_image, int p_direction, int p_sort_mode,
                       double p_threshold_low, double p_threshold_high, bool p_reverse) const;

private:
    static double _get_brightness(const Color &c);
    static double _get_sort_key(const Color &c, int mode);
    static void _sort_span(Color *pixels, double *keys, int start, int end, bool reverse);
};

} // namespace godot

VARIANT_ENUM_CAST(GNNativePixelSort::SortDirection);
VARIANT_ENUM_CAST(GNNativePixelSort::SortMode);

#endif // GN_NATIVE_PIXEL_SORT_H
