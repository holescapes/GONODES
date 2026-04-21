#ifndef GN_NATIVE_CREEP_SOP_H
#define GN_NATIVE_CREEP_SOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
namespace godot {
class GNNativeCreepSop : public RefCounted {
    GDCLASS(GNNativeCreepSop, RefCounted)
public:
    // Projects source points onto target surface (nearest triangle), then displaces
    PackedVector3Array process(const PackedVector3Array &source_pts,
                               const PackedVector3Array &target_verts,
                               const PackedInt32Array &target_indices,
                               const PackedVector3Array &target_normals,
                               int direction, double distance, int seed);
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
