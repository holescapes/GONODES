#ifndef GN_NATIVE_POLYBEVEL_SOP_H
#define GN_NATIVE_POLYBEVEL_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// Vertex-pull edge bevel with optional multi-division rounding.
class GNNativePolyBevelSop : public RefCounted {
    GDCLASS(GNNativePolyBevelSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns Dictionary {"positions": PV3A, "normals": PV3A, "indices": PI32A}.
    Dictionary process(const PackedVector3Array &positions,
                       const PackedVector3Array &normals,
                       const PackedInt32Array &indices,
                       double offset, int divisions, double roundness);
};

} // namespace godot

#endif // GN_NATIVE_POLYBEVEL_SOP_H
