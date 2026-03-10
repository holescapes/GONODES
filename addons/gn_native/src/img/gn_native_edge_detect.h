#ifndef GN_NATIVE_EDGE_DETECT_H
#define GN_NATIVE_EDGE_DETECT_H

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

/// Sobel/Prewitt edge detection on a CPU image.
/// Computes luminance, applies 3×3 convolution kernels.
class GNNativeEdgeDetect : public RefCounted {
    GDCLASS(GNNativeEdgeDetect, RefCounted)

protected:
    static void _bind_methods();

public:
    /// kernel: 0=Sobel, 1=Prewitt
    Ref<Image> process(const Ref<Image> &p_image, int kernel,
                       double strength, bool invert, bool color_edges) const;
};

} // namespace godot

#endif // GN_NATIVE_EDGE_DETECT_H
