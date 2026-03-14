#ifndef GN_NATIVE_ATTRIBUTE_SOP_H
#define GN_NATIVE_ATTRIBUTE_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

/// Generates per-vertex attribute values from expression, position, constant, or random.
class GNNativeAttributeSop : public RefCounted {
    GDCLASS(GNNativeAttributeSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// source: 0=const, 1=expr, 2=px, 3=py, 4=pz, 5=ny, 6=uv_u, 7=random.
    PackedFloat32Array process(const PackedVector3Array &verts,
                               const PackedVector3Array &normals,
                               const PackedVector2Array &uvs,
                               int source, double const_val,
                               const String &expression, double time_val,
                               int seed, double rand_min, double rand_max);
};

} // namespace godot

#endif
