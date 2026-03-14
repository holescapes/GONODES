#ifndef GN_NATIVE_CHECKERBOARD_IMG_H
#define GN_NATIVE_CHECKERBOARD_IMG_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/color.hpp>

namespace godot {

/// CPU checkerboard pattern generator.
class GNNativeCheckerboardImg : public RefCounted {
    GDCLASS(GNNativeCheckerboardImg, RefCounted)

protected:
    static void _bind_methods();

public:
    Ref<Image> process(int width, int height, int cells_x, int cells_y,
                       const Color &color_a, const Color &color_b,
                       double softness);
};

} // namespace godot

#endif
