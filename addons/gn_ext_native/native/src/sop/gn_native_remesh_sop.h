#ifndef GN_NATIVE_REMESH_SOP_H
#define GN_NATIVE_REMESH_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// Edge-length based midpoint subdivision with optional Laplacian smooth.
class GNNativeRemeshSop : public RefCounted {
    GDCLASS(GNNativeRemeshSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns Dictionary {"positions": PV3A, "normals": PV3A, "indices": PI32A}.
    Dictionary process(const PackedVector3Array &positions,
                       const PackedInt32Array &indices,
                       double target_edge, int iterations, bool smooth);
};

} // namespace godot

#endif // GN_NATIVE_REMESH_SOP_H
