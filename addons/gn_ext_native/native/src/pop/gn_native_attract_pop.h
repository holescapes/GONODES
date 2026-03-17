#ifndef GN_NATIVE_ATTRACT_POP_H
#define GN_NATIVE_ATTRACT_POP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// Point attractor with inverse-square falloff (CPU path).
class GNNativeAttractPop : public RefCounted {
    GDCLASS(GNNativeAttractPop, RefCounted)

protected:
    static void _bind_methods();

public:
    PackedVector3Array process(const PackedVector3Array &positions,
                               const PackedVector3Array &velocities,
                               double target_x, double target_y, double target_z,
                               double strength, double radius, double dt);
};

} // namespace godot

#endif // GN_NATIVE_ATTRACT_POP_H
