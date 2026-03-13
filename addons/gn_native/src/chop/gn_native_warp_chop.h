#ifndef GN_NATIVE_WARP_CHOP_H
#define GN_NATIVE_WARP_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Time-warps CHOP channels by remapping sample indices via a warp curve.
class GNNativeWarpChop : public RefCounted {
    GDCLASS(GNNativeWarpChop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Warps channels_a samples using channels_b as lookup indices.
    /// quality: 0=Linear, 1=Nearest
    Dictionary process(const Dictionary &channels_a,
                       const PackedFloat32Array &warp_curve, int quality);
};

} // namespace godot

#endif // GN_NATIVE_WARP_CHOP_H
