#ifndef GN_NATIVE_SUBDIVIDE_H
#define GN_NATIVE_SUBDIVIDE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace godot {

/// Triangle subdivision: splits each triangle into 4 by inserting edge midpoints.
/// Supports multiple iterations (face count × 4^iters).
class GNNativeSubdivide : public RefCounted {
    GDCLASS(GNNativeSubdivide, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns Dictionary { "positions": PV3A, "uvs": PV2A, "indices": PI32A }
    Dictionary process(const PackedVector3Array &positions,
                       const PackedVector2Array &uvs,
                       const PackedInt32Array &indices,
                       int iterations);
};

} // namespace godot

#endif // GN_NATIVE_SUBDIVIDE_H
