#ifndef GN_NATIVE_SORT_SOP_H
#define GN_NATIVE_SORT_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace godot {

/// Sorts vertex arrays by axis, distance, random, or reverse.
/// Returns remapped vertex/normal/uv/tangent/index arrays.
class GNNativeSortSop : public RefCounted {
    GDCLASS(GNNativeSortSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// method: 0-5 (X,Y,Z,distance,random,reverse). Returns remapped arrays.
    Dictionary process(const PackedVector3Array &verts,
                       const PackedVector3Array &normals,
                       const PackedVector2Array &uvs,
                       const PackedFloat32Array &tangents,
                       const PackedInt32Array &indices,
                       int method, const Vector3 &ref_point, int seed);
};

} // namespace godot

#endif
