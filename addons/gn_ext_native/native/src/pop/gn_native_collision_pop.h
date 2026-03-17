#ifndef GN_NATIVE_COLLISION_POP_H
#define GN_NATIVE_COLLISION_POP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// Ground plane collision with bounce/friction and kill-below (CPU path).
class GNNativeCollisionPop : public RefCounted {
    GDCLASS(GNNativeCollisionPop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns Dictionary with compacted particle arrays.
    Dictionary process(const PackedVector3Array &positions,
                       const PackedVector3Array &velocities,
                       const PackedFloat32Array &ages,
                       const PackedFloat32Array &lives,
                       int count, double ground_y, double bounce,
                       double friction, double kill_below);
};

} // namespace godot

#endif // GN_NATIVE_COLLISION_POP_H
