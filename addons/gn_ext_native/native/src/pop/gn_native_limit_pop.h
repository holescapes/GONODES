#ifndef GN_NATIVE_LIMIT_POP_H
#define GN_NATIVE_LIMIT_POP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// Bounding box kill + speed clamping for particles (CPU path).
class GNNativeLimitPop : public RefCounted {
    GDCLASS(GNNativeLimitPop, RefCounted)

protected:
    static void _bind_methods();

public:
    Dictionary process(const PackedVector3Array &positions,
                       const PackedVector3Array &velocities,
                       const PackedFloat32Array &ages,
                       const PackedFloat32Array &lives,
                       int count,
                       double bbox_min_x, double bbox_min_y, double bbox_min_z,
                       double bbox_max_x, double bbox_max_y, double bbox_max_z,
                       double max_speed, bool kill_outside);
};

} // namespace godot

#endif // GN_NATIVE_LIMIT_POP_H
