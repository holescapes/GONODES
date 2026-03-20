#ifndef GN_NATIVE_BLEND_CHOP_H
#define GN_NATIVE_BLEND_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/typed_array.hpp>

namespace godot {

/// Weighted blend of N input channel data arrays.
class GNNativeBlendChop : public RefCounted {
    GDCLASS(GNNativeBlendChop, RefCounted)

public:
    /// Blend multiple PackedFloat32Arrays with weights.
    /// p_inputs: Array of PackedFloat32Array
    /// p_weights: PackedFloat32Array of weights (one per input)
    PackedFloat32Array process(const TypedArray<PackedFloat32Array> &p_inputs,
                                const PackedFloat32Array &p_weights) const;

protected:
    static void _bind_methods();
};

} // namespace godot

#endif
