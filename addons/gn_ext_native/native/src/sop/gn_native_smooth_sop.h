#ifndef GN_NATIVE_SMOOTH_SOP_H
#define GN_NATIVE_SMOOTH_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// Iterative Laplacian vertex smoothing with optional border pinning.
class GNNativeSmoothSop : public RefCounted {
    GDCLASS(GNNativeSmoothSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns Dictionary {"positions": PV3A, "normals": PV3A}.
    Dictionary process(const PackedVector3Array &positions,
                       const PackedInt32Array &indices,
                       int iterations, double strength, bool pin_borders);
};

} // namespace godot

#endif // GN_NATIVE_SMOOTH_SOP_H
