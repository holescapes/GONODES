#ifndef GN_NATIVE_MIRROR_SOP_H
#define GN_NATIVE_MIRROR_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace godot {

/// Mirrors vertex positions and normals across a plane, optionally reversing winding.
class GNNativeMirrorSop : public RefCounted {
    GDCLASS(GNNativeMirrorSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns {"positions": PV3A, "normals": PV3A, "indices": PI32A}.
    Dictionary process(const PackedVector3Array &verts,
                       const PackedVector3Array &normals,
                       const PackedInt32Array &indices,
                       const Vector3 &mirror_axis, double origin,
                       bool reverse_winding);
};

} // namespace godot

#endif
