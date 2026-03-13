#ifndef GN_NATIVE_SCATTER_SOP_H
#define GN_NATIVE_SCATTER_SOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
namespace godot {
/// Scatter random points on triangle mesh surface via area-weighted sampling.
class GNNativeScatterSop : public RefCounted {
    GDCLASS(GNNativeScatterSop, RefCounted)
protected:
    static void _bind_methods();
public:
    /// Returns {"positions": PV3A, "normals": PV3A, "uvs": PV2A}
    Dictionary process(const PackedVector3Array &verts,
                       const PackedVector3Array &normals,
                       const PackedVector2Array &uvs,
                       const PackedInt32Array &indices,
                       int count, int seed,
                       bool emit_normals, bool emit_uvs);
};
} // namespace godot
#endif
