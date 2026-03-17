#ifndef GN_NATIVE_WIREFRAME_SOP_H
#define GN_NATIVE_WIREFRAME_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// Extracts unique edges from a triangle mesh as line segments.
class GNNativeWireframeSop : public RefCounted {
    GDCLASS(GNNativeWireframeSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns PackedVector3Array of line-pair vertices (2 per edge).
    PackedVector3Array process(const PackedVector3Array &positions,
                               const PackedInt32Array &indices);
};

} // namespace godot

#endif // GN_NATIVE_WIREFRAME_SOP_H
