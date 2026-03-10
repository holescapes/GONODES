#ifndef GN_NATIVE_COPY_H
#define GN_NATIVE_COPY_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Copies template geometry onto each target point with transform.
/// High-throughput: handles millions of vertex transforms.
class GNNativeCopy : public RefCounted {
    GDCLASS(GNNativeCopy, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns Dictionary { "positions": PV3A, "normals": PV3A, "uvs": PV2A, "indices": PI32A }
    Dictionary process(const PackedVector3Array &tmpl_positions,
                       const PackedVector3Array &tmpl_normals,
                       const PackedVector2Array &tmpl_uvs,
                       const PackedInt32Array &tmpl_indices,
                       const PackedVector3Array &target_positions,
                       const PackedVector3Array &target_normals,
                       const PackedFloat32Array &pscale,
                       bool align_to_normal, double base_scale);
};

} // namespace godot

#endif // GN_NATIVE_COPY_H
