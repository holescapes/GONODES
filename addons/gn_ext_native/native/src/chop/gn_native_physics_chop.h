#ifndef GN_NATIVE_PHYSICS_CHOP_H
#define GN_NATIVE_PHYSICS_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Simple physics simulation on CHOP channels (gravity, spring, velocity integration).
/// Maintains per-channel position and velocity state.
class GNNativePhysicsChop : public RefCounted {
    GDCLASS(GNNativePhysicsChop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Simulates physics on input channels: input value = target, output = simulated position.
    Dictionary process(const Dictionary &channels, double dt,
                       double mass, double stiffness, double damping,
                       double gravity, bool reset);
    void clear_state();

private:
    struct PhysState {
        double pos = 0.0;
        double vel = 0.0;
    };
    HashMap<String, PhysState> _state;
};

} // namespace godot

#endif // GN_NATIVE_PHYSICS_CHOP_H
