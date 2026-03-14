#ifndef GN_NATIVE_BLEND_SOP_H
#define GN_NATIVE_BLEND_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>

namespace godot {

/// Morphs between two geometries by interpolating vertex data.
class GNNativeBlendSop : public RefCounted {
    GDCLASS(GNNativeBlendSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns {"positions": PV3A, "normals": PV3A, "uvs": PV2A}
    Dictionary process(const PackedVector3Array &verts_a,
                       const PackedVector3Array &verts_b,
                       const PackedVector3Array &normals_a,
                       const PackedVector3Array &normals_b,
                       const PackedVector2Array &uvs_a,
                       const PackedVector2Array &uvs_b,
                       double blend, bool do_normals, bool do_uvs);
};

} // namespace godot

#endif
