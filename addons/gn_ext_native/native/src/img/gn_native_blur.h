#ifndef GN_NATIVE_BLUR_H
#define GN_NATIVE_BLUR_H

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

/// Native separable box blur processor.
/// Takes a Godot Image and returns a blurred copy.
/// Multi-pass support for Gaussian approximation.
class GNNativeBlur : public RefCounted {
    GDCLASS(GNNativeBlur, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Performs a multi-pass separable box blur on the input image.
    /// @param p_image   Source image (not modified).
    /// @param p_radius  Kernel half-width in pixels.
    /// @param p_passes  Number of sequential blur passes.
    /// @return          New blurred image.
    Ref<Image> process(const Ref<Image> &p_image, int p_radius, int p_passes) const;

private:
    Ref<Image> _box_blur(const Ref<Image> &p_src, int p_width, int p_height, int p_radius) const;
};

} // namespace godot

#endif // GN_NATIVE_BLUR_H
