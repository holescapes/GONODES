#ifndef GN_NATIVE_CAP_SOP_H
#define GN_NATIVE_CAP_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace godot {

/// Detects boundary edges and fills holes with triangle fan caps.
class GNNativeCapSop : public RefCounted {
    GDCLASS(GNNativeCapSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns {"positions": PV3A, "normals": PV3A} — cap triangles to append.
    Dictionary process(const PackedVector3Array &all_positions,
                       const PackedInt32Array &all_indices,
                       bool flip_normals);
};

} // namespace godot

#endif
