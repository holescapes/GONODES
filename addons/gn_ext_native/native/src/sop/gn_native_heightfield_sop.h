#ifndef GN_NATIVE_HEIGHTFIELD_SOP_H
#define GN_NATIVE_HEIGHTFIELD_SOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
namespace godot {
class GNNativeHeightfieldSop : public RefCounted {
    GDCLASS(GNNativeHeightfieldSop, RefCounted)
public:
    // Generate heightfield mesh from height data
    // Returns Dictionary with "vertices", "normals", "uvs", "indices"
    Dictionary process(const PackedFloat32Array &heights, int rows, int cols,
                       double size_x, double size_z, double height_scale);
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
