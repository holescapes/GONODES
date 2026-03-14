#ifndef GN_NATIVE_TRANSFORM_SOP_H
#define GN_NATIVE_TRANSFORM_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/transform3d.hpp>

namespace godot {

/// Applies a Transform3D to vertex positions and normals.
class GNNativeTransformSop : public RefCounted {
    GDCLASS(GNNativeTransformSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns {"positions": PV3A, "normals": PV3A}.
    Dictionary process(const PackedVector3Array &verts,
                       const PackedVector3Array &normals,
                       const Transform3D &xform);
};

} // namespace godot

#endif
