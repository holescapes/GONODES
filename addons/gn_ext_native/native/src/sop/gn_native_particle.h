#ifndef GN_NATIVE_PARTICLE_H
#define GN_NATIVE_PARTICLE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <vector>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

/// Native CPU particle simulator.
///
/// Holds particle state (positions, velocities, ages, lives) across cooks.
/// The GDScript wrapper calls step() each frame, passing emitter geometry
/// and simulation parameters;  step() returns a Dictionary with the updated
/// packed arrays ready for point-cloud mesh assembly.
class GNNativeParticle : public RefCounted {
    GDCLASS(GNNativeParticle, RefCounted)

protected:
    static void _bind_methods();

public:
    GNNativeParticle();

    /// Build the area-weighted CDF from emitter triangles.
    /// @param p_vertices  Packed vertex positions of emitter mesh (flat triangles or indexed).
    /// @param p_normals   Per-vertex normals (same count as vertices), or empty.
    /// @param p_indices   Triangle indices (empty → non-indexed, treat vertices as flat tris).
    void set_emitter(const PackedVector3Array &p_vertices,
                     const PackedVector3Array &p_normals,
                     const PackedInt32Array &p_indices);

    /// Advance the particle simulation by one timestep.
    /// Returns a Dictionary:
    ///   "positions"  → PackedVector3Array
    ///   "ages"       → PackedFloat32Array
    ///   "lives"      → PackedFloat32Array
    ///   "age_norm"   → PackedFloat32Array
    ///   "count"      → int
    Dictionary step(double p_dt,
                    double p_rate, int p_max_particles,
                    double p_life, double p_life_rand,
                    double p_emit_speed, double p_speed_rand, double p_spread,
                    double p_gravity, double p_drag, double p_turbulence,
                    double p_attract_force, const Vector3 &p_attractor_pos,
                    bool p_floor_enabled, double p_floor_y, double p_bounce,
                    int p_seed);

    /// Clear all particles (reset state).
    void reset();

    int get_particle_count() const;

private:
    // Particle state
    PackedVector3Array _positions;
    PackedVector3Array _velocities;
    PackedFloat32Array _ages;
    PackedFloat32Array _lives;
    int _next_id;
    double _emit_accum;

    // Emitter cache
    struct Triangle {
        Vector3 v[3];
        Vector3 n[3];
        bool has_normals;
    };
    std::vector<Triangle> _triangles;
    PackedFloat64Array _tri_cdf;
    double _tri_total_area;

    // RNG state (xorshift64)
    uint64_t _rng_state;

    double _randf();
    double _randf_range(double lo, double hi);
    void _spawn_particle(double life_base, double life_rand,
                         double speed, double speed_rand, double spread);
    void _remove_particle(int idx);
};

} // namespace godot

#endif // GN_NATIVE_PARTICLE_H
