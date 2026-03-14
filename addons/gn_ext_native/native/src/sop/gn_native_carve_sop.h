#ifndef GN_NATIVE_CARVE_SOP_H
#define GN_NATIVE_CARVE_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace godot {

/// Trims triangles by parametric U range (index-based, UV-based, or position-based).
class GNNativeCarveSop : public RefCounted {
    GDCLASS(GNNativeCarveSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns {"positions": PV3A, "normals": PV3A, "uvs": PV2A} — kept triangles.
    Dictionary process(const PackedVector3Array &verts,
                       const PackedVector3Array &normals,
                       const PackedVector2Array &uvs,
                       const PackedInt32Array &indices,
                       double first_u, double second_u,
                       bool extract, bool use_uvs,
                       bool use_position, int axis);
};

} // namespace godot

#endif
