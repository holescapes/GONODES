#ifndef GN_NATIVE_POLYLOFT_SOP_H
#define GN_NATIVE_POLYLOFT_SOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
namespace godot {
/// Lofts a surface between two or more cross-section polylines.
class GNNativePolyLoftSop : public RefCounted {
    GDCLASS(GNNativePolyLoftSop, RefCounted)
protected:
    static void _bind_methods();
public:
    /// cross_sections: array of PackedVector3Arrays (each is a profile)
    /// Returns {"positions", "normals", "uvs", "indices"}
    Dictionary process(const Array &cross_sections, bool close_profiles);
};
} // namespace godot
#endif
