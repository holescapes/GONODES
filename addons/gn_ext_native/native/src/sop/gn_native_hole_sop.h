#ifndef GN_NATIVE_HOLE_SOP_H
#define GN_NATIVE_HOLE_SOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
namespace godot {
class GNNativeHoleSop : public RefCounted {
    GDCLASS(GNNativeHoleSop, RefCounted)
public:
    // Returns indices of triangles to keep (those whose centroids are NOT inside the hole polygon)
    PackedInt32Array process(const PackedVector3Array &mesh_verts,
                             const PackedInt32Array &mesh_indices,
                             const PackedVector3Array &hole_points,
                             int project_axis, bool invert);
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
