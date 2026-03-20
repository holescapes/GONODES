#ifndef GN_NATIVE_CLOTH_SOP_H
#define GN_NATIVE_CLOTH_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

/// Verlet-integration cloth simulation processor.
/// Maintains simulation state (positions, prev_positions, edges, pins)
/// across calls. GDScript wrapper feeds arrays and reads back results.
class GNNativeClothSop : public RefCounted {
    GDCLASS(GNNativeClothSop, RefCounted)

public:
    /// Initialize simulation from mesh data. Builds edge list and pin set.
    void init_simulation(const PackedVector3Array &p_positions,
                         const PackedInt32Array &p_indices,
                         const PackedInt32Array &p_pinned);

    /// Run one simulation step: Verlet + N constraint iterations + pin enforce.
    void step(double p_dt, double p_gravity, double p_damping,
              const Vector3 &p_wind, int p_iterations, double p_stiffness);

    /// Get current positions after stepping.
    PackedVector3Array get_positions() const;

    /// Recompute smooth normals from current positions and stored indices.
    PackedVector3Array compute_normals() const;

    /// Reset simulation (clear all state).
    void reset();

    /// Returns true if simulation has been initialized.
    bool is_initialized() const;

protected:
    static void _bind_methods();

private:
    PackedVector3Array _positions;
    PackedVector3Array _prev_positions;
    PackedInt32Array _indices; // triangle indices (for normal recompute)
    // Edge constraint arrays
    PackedInt32Array _edge_a;
    PackedInt32Array _edge_b;
    PackedFloat32Array _rest_lengths;
    // Pinned vertex indices
    PackedInt32Array _pinned;
    bool _initialized = false;
};

} // namespace godot

#endif // GN_NATIVE_CLOTH_SOP_H
