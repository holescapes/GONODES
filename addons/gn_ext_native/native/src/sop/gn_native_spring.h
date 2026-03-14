#ifndef GN_NATIVE_SPRING_H
#define GN_NATIVE_SPRING_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// Per-vertex damped spring integrator.
/// Maintains internal position/velocity state across calls.
class GNNativeSpring : public RefCounted {
    GDCLASS(GNNativeSpring, RefCounted)

protected:
    static void _bind_methods();

public:
    GNNativeSpring() = default;

    /// Integrates one timestep. Returns deformed positions.
    /// On first call or after reset, initialises state from targets.
    PackedVector3Array step(const PackedVector3Array &target_positions,
                            double dt, double stiffness, double damping,
                            double mass, double max_displacement, bool reset);

private:
    PackedVector3Array _positions;
    PackedVector3Array _velocities;
    bool _initialized = false;
};

} // namespace godot

#endif // GN_NATIVE_SPRING_H
