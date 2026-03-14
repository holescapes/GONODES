#ifndef GN_NATIVE_TOP_TO_SOP_H
#define GN_NATIVE_TOP_TO_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

/// Converts an Image into mesh arrays (heightfield, point cloud, or normal-map grid).
class GNNativeTopToSop : public RefCounted {
    GDCLASS(GNNativeTopToSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// mode: 0=heightfield, 1=point cloud, 2=normal map grid.
    /// channel: 0=luminance, 1=R, 2=G, 3=B, 4=A.
    Dictionary process(const Ref<Image> &img, int mode, int resolution,
                       double height_scale, double grid_size,
                       double threshold, int channel);

private:
    float _sample_channel(const Color &c, int channel);
};

} // namespace godot

#endif
