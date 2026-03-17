#ifndef GN_NATIVE_BLEND_VOL_H
#define GN_NATIVE_BLEND_VOL_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Blends two volumes with configurable operations (CPU path).
class GNNativeBlendVol : public RefCounted {
    GDCLASS(GNNativeBlendVol, RefCounted)

protected:
    static void _bind_methods();

public:
    /// op: 0=add, 1=subtract, 2=multiply, 3=max, 4=min, 5=mix
    PackedFloat32Array process(const PackedFloat32Array &vol_a,
                               const PackedFloat32Array &vol_b,
                               int total_elements, int op,
                               double mix_factor, double scale_a, double scale_b);
};

} // namespace godot

#endif // GN_NATIVE_BLEND_VOL_H
