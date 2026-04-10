#ifndef GN_NATIVE_BOOLEAN_SOP_H
#define GN_NATIVE_BOOLEAN_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// BSP-tree boolean operations (union, intersection, subtraction) on triangle meshes.
class GNNativeBooleanSop : public RefCounted {
    GDCLASS(GNNativeBooleanSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// @param positions_a Vertices of mesh A.
    /// @param indices_a   Triangle indices of mesh A.
    /// @param positions_b Vertices of mesh B.
    /// @param indices_b   Triangle indices of mesh B.
    /// @param operation   0 = Union, 1 = Intersection, 2 = Subtraction (A - B).
    /// @return Dictionary {"positions": PV3A, "indices": PI32A, "normals": PV3A}
    Dictionary process(const PackedVector3Array &positions_a,
                       const PackedInt32Array &indices_a,
                       const PackedVector3Array &positions_b,
                       const PackedInt32Array &indices_b,
                       int operation);
};

} // namespace godot

#endif // GN_NATIVE_BOOLEAN_SOP_H
