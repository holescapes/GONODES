#ifndef GN_NATIVE_INSTANCE_POP_H
#define GN_NATIVE_INSTANCE_POP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// Stamps source geometry at each particle position.
/// Returns {"positions": PV3A, "normals": PV3A, "indices": PI32A, "colors": PCA}.
class GNNativeInstancePop : public RefCounted {
    GDCLASS(GNNativeInstancePop, RefCounted)

protected:
    static void _bind_methods();

public:
    Dictionary process(const PackedVector3Array &positions,
                       const PackedFloat32Array &pscales,
                       const PackedVector3Array &src_verts,
                       const PackedVector3Array &src_normals,
                       const PackedInt32Array &src_indices,
                       const PackedFloat32Array &colors_flat,
                       int max_instances, bool use_pscale, bool use_color);
};

} // namespace godot

#endif
