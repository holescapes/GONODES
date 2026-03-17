#ifndef GN_NATIVE_SOURCE_POP_H
#define GN_NATIVE_SOURCE_POP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// Particle emitter: ages existing particles, kills expired, emits new (CPU path).
class GNNativeSourcePop : public RefCounted {
    GDCLASS(GNNativeSourcePop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns Dictionary with compacted + newly emitted particle arrays.
    Dictionary process(const PackedVector3Array &positions,
                       const PackedVector3Array &velocities,
                       const PackedFloat32Array &ages,
                       const PackedFloat32Array &lives,
                       const PackedFloat32Array &pscales,
                       int particle_count, int max_particles,
                       const PackedVector3Array &emit_points,
                       int emit_count_this_frame,
                       double life_min, double life_max,
                       double init_speed, double pscale, double dt,
                       double seed_time);
};

} // namespace godot

#endif // GN_NATIVE_SOURCE_POP_H
