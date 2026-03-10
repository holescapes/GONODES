#ifndef GN_NATIVE_RAY_H
#define GN_NATIVE_RAY_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Möller–Trumbore ray-triangle intersection for projecting vertices
/// onto a target surface. Brute-force O(V×T) in this version.
class GNNativeRay : public RefCounted {
    GDCLASS(GNNativeRay, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Project source vertices onto target triangles.
    /// direction: 0=normal, 1=-Y, 2=+Y, 3=-Z, 4=+Z, 5=-X, 6=+X
    /// Returns Dictionary { "positions": PV3A, "normals": PV3A }
    Dictionary process(const PackedVector3Array &src_positions,
                       const PackedVector3Array &src_normals,
                       const PackedVector3Array &target_faces,
                       int direction, double max_dist, double offset,
                       bool use_hit_normal);
};

} // namespace godot

#endif // GN_NATIVE_RAY_H
