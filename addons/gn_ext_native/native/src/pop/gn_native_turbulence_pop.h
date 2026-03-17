#ifndef GN_NATIVE_TURBULENCE_POP_H
#define GN_NATIVE_TURBULENCE_POP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// Curl noise turbulence force on particles (CPU path).
class GNNativeTurbulencePop : public RefCounted {
    GDCLASS(GNNativeTurbulencePop, RefCounted)

protected:
    static void _bind_methods();

public:
    PackedVector3Array process(const PackedVector3Array &positions,
                               const PackedVector3Array &velocities,
                               int count, double amplitude, double frequency,
                               double time_val, double roughness, int octaves,
                               double dt);
};

} // namespace godot

#endif // GN_NATIVE_TURBULENCE_POP_H
