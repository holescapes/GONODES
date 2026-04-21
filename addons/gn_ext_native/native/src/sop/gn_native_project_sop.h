#ifndef GN_NATIVE_PROJECT_SOP_H
#define GN_NATIVE_PROJECT_SOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
namespace godot {
class GNNativeProjectSop : public RefCounted {
    GDCLASS(GNNativeProjectSop, RefCounted)
public:
    // Orthographic projection of source points onto target surface along axis
    PackedVector3Array process(const PackedVector3Array &source_pts,
                               const PackedVector3Array &target_verts,
                               const PackedInt32Array &target_indices,
                               int axis); // 0=X, 1=Y, 2=Z
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
