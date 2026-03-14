#ifndef GN_NATIVE_DELETE_SOP_H
#define GN_NATIVE_DELETE_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace godot {

/// Deletes triangles by range, bounding box, or random percentage.
class GNNativeDeleteSop : public RefCounted {
    GDCLASS(GNNativeDeleteSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// method: 0=range, 1=bbox, 2=random%.
    /// Returns {"positions": PV3A, "normals": PV3A, "uvs": PV2A} — kept triangles only.
    Dictionary process(const PackedVector3Array &verts,
                       const PackedVector3Array &normals,
                       const PackedVector2Array &uvs,
                       const PackedInt32Array &indices,
                       int method, int start, int end,
                       const Vector3 &bmin, const Vector3 &bmax,
                       double percent, int seed, bool invert);
};

} // namespace godot

#endif
