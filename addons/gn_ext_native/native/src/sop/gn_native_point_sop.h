#ifndef GN_NATIVE_POINT_SOP_H
#define GN_NATIVE_POINT_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

/// Per-vertex position expression evaluator.
/// Uses Godot Expression class from C++ to minimise loop overhead.
class GNNativePointSop : public RefCounted {
    GDCLASS(GNNativePointSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns {"positions": PV3A} — new vertex positions after expression evaluation.
    Dictionary process(const PackedVector3Array &verts,
                       const PackedVector3Array &normals,
                       const PackedVector2Array &uvs,
                       const String &expr_x, const String &expr_y,
                       const String &expr_z, double time_val);
};

} // namespace godot

#endif
