#ifndef GN_NATIVE_PRIMITIVE_SOP_H
#define GN_NATIVE_PRIMITIVE_SOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
namespace godot {
class GNNativePrimitiveSop : public RefCounted {
    GDCLASS(GNNativePrimitiveSop, RefCounted)
public:
    // Returns Dictionary with "vertices", "normals", "uvs", "indices"
    Dictionary process(int prim_type, int rows, int columns, double radius,
                       double size_x, double size_y, double size_z);
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
