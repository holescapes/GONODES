#include "gn_native_physics_chop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativePhysicsChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "channels", "dt", "mass",
                                  "stiffness", "damping", "gravity", "reset"),
                         &GNNativePhysicsChop::process);
    ClassDB::bind_method(D_METHOD("clear_state"), &GNNativePhysicsChop::clear_state);
}

void GNNativePhysicsChop::clear_state() {
    _state.clear();
}

Dictionary GNNativePhysicsChop::process(const Dictionary &channels, double dt,
                                         double mass, double stiffness,
                                         double damping, double gravity,
                                         bool reset) {
    if (reset) _state.clear();
    if (dt <= 0.0) dt = 1.0 / 60.0;
    if (mass < 0.001) mass = 0.001;

    Dictionary out;
    Array keys = channels.keys();

    for (int ki = 0; ki < keys.size(); ++ki) {
        String name = keys[ki];
        PackedFloat32Array data = channels[name];
        int count = data.size();
        if (count == 0) continue;

        const float *in_ptr = data.ptr();

        if (!_state.has(name)) {
            _state[name] = PhysState{(double)in_ptr[count - 1], 0.0};
        }
        PhysState &st = _state[name];

        PackedFloat32Array result;
        result.resize(count);
        float *out_ptr = result.ptrw();

        for (int i = 0; i < count; ++i) {
            double target = (double)in_ptr[i];

            // Spring force toward target
            double spring_force = stiffness * (target - st.pos);
            // Damping force opposing velocity
            double damp_force = -damping * st.vel;
            // Gravity (applied on Y-like channels, but we apply universally)
            double accel = (spring_force + damp_force) / mass + gravity;

            st.vel += accel * dt;
            st.pos += st.vel * dt;

            out_ptr[i] = (float)st.pos;
        }

        out[name] = result;
    }

    return out;
}

} // namespace godot
