#ifndef GN_NATIVE_COMPOSITE_CHOP_H
#define GN_NATIVE_COMPOSITE_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Weighted blend of channels from multiple inputs.
class GNNativeCompositeChop : public RefCounted {
    GDCLASS(GNNativeCompositeChop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// op: 0=Weighted Average, 1=Add, 2=Max, 3=Min
    /// inputs: Array of Dictionary (each a channel map String→PackedFloat32Array)
    Dictionary process(const Array &inputs, const PackedFloat32Array &weights, int op);
};

} // namespace godot

#endif // GN_NATIVE_COMPOSITE_CHOP_H
