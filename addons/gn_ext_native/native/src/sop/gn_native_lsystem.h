#ifndef GN_NATIVE_LSYSTEM_H
#define GN_NATIVE_LSYSTEM_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

/// L-System string rewriting + turtle interpretation + tube mesh generation.
/// Handles the full pipeline: grammar → segments → tube/line geometry.
class GNNativeLSystem : public RefCounted {
    GDCLASS(GNNativeLSystem, RefCounted)

protected:
    static void _bind_methods();

public:
    /// axiom, rules_str = "F=F[+F]F[-F]F;G=FF" (semicolon-separated)
    /// Returns Dictionary { "positions": PV3A, "normals": PV3A }
    /// For tube mode (tube_radius > 0), returns triangle mesh.
    /// For line mode, returns line pairs.
    Dictionary process(const String &axiom, const String &rules_str,
                       int iterations, double step_size, double angle_deg,
                       double step_scale, double angle_rand, int seed,
                       double tube_radius, int tube_sides, double taper,
                       double gravity);
};

} // namespace godot

#endif // GN_NATIVE_LSYSTEM_H
