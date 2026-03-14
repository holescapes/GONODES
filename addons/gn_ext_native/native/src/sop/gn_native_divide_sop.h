#ifndef GN_NATIVE_DIVIDE_SOP_H
#define GN_NATIVE_DIVIDE_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace godot {

/// Removes degenerate triangles from a triangle mesh.
class GNNativeDivideSop : public RefCounted {
    GDCLASS(GNNativeDivideSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns {"indices": PI32A} with degenerate triangles removed.
    PackedInt32Array remove_degenerate(const PackedVector3Array &verts,
                                       const PackedInt32Array &indices);
};

} // namespace godot

#endif
