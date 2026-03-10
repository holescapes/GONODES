#include "gn_native_spring.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeSpring::_bind_methods() {
    ClassDB::bind_method(D_METHOD("step", "target_positions", "dt",
                                  "stiffness", "damping", "mass",
                                  "max_displacement", "reset"),
                         &GNNativeSpring::step);
}

PackedVector3Array GNNativeSpring::step(const PackedVector3Array &target_positions,
                                         double dt, double stiffness, double damping,
                                         double mass, double max_displacement, bool reset) {
    int n = target_positions.size();
    if (n == 0) return PackedVector3Array();

    // Reset or first call: initialize state from targets
    if (reset || !_initialized || (int)_positions.size() != n) {
        _positions = target_positions;
        _velocities.resize(n);
        Vector3 *vp = _velocities.ptrw();
        for (int i = 0; i < n; ++i) vp[i] = Vector3(0, 0, 0);
        _initialized = true;
        return _positions;
    }

    float fdt = (float)dt;
    float k = (float)stiffness;
    float c = (float)damping;
    float m = (float)fmax(mass, 0.001);
    float max_disp = (float)max_displacement;

    const Vector3 *target = target_positions.ptr();
    Vector3 *pos = _positions.ptrw();
    Vector3 *vel = _velocities.ptrw();

    for (int i = 0; i < n; ++i) {
        // Spring force: F = -k * (pos - target) - c * vel
        Vector3 displacement = pos[i] - target[i];
        Vector3 force = -displacement * k - vel[i] * c;
        Vector3 accel = force / m;

        // Semi-implicit Euler integration
        vel[i] += accel * fdt;
        pos[i] += vel[i] * fdt;

        // Clamp maximum displacement from rest position
        if (max_disp > 0.0f) {
            Vector3 disp = pos[i] - target[i];
            float dist = disp.length();
            if (dist > max_disp) {
                pos[i] = target[i] + disp * (max_disp / dist);
                // Project out radial velocity component to prevent further divergence
                Vector3 dir = disp / dist;
                float radial = vel[i].dot(dir);
                if (radial > 0.0f) vel[i] -= dir * radial;
            }
        }
    }

    return _positions;
}

} // namespace godot
