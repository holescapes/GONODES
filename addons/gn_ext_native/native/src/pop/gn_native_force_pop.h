#ifndef GN_NATIVE_FORCE_POP_H
#define GN_NATIVE_FORCE_POP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// Gravity, wind, and drag force integration (CPU path).
class GNNativeForcePop : public RefCounted {
    GDCLASS(GNNativeForcePop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns Dictionary {"positions": PV3A, "velocities": PV3A}.
    Dictionary process(const PackedVector3Array &positions,
                       const PackedVector3Array &velocities,
                       int count, double fx, double fy, double fz,
                       double drag, double dt);
};

} // namespace godot

#endif // GN_NATIVE_FORCE_POP_H
