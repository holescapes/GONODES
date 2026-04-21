#ifndef GN_NATIVE_MEASURE_SOP_H
#define GN_NATIVE_MEASURE_SOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
namespace godot {
class GNNativeMeasureSop : public RefCounted {
    GDCLASS(GNNativeMeasureSop, RefCounted)
public:
    // Returns Dictionary with "area", "perimeter", "curvature" (PackedFloat32Array per-vertex)
    Dictionary process(const PackedVector3Array &vertices, const PackedInt32Array &indices);
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
