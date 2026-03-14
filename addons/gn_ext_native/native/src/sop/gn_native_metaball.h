#ifndef GN_NATIVE_METABALL_H
#define GN_NATIVE_METABALL_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

using namespace godot;

/// Marching-cubes metaball iso-surface extractor.
/// Evaluates an implicit field from ball primitives then extracts the
/// iso-surface as a triangle mesh.  Called from GDScript MetaballSOP wrapper.
class GNNativeMetaball : public RefCounted {
    GDCLASS(GNNativeMetaball, RefCounted);

protected:
    static void _bind_methods();

public:
    GNNativeMetaball();
    ~GNNativeMetaball() = default;

    /// Main entry: returns Dictionary { "positions": PV3A, "normals": PV3A }
    Dictionary process(const PackedVector3Array &ball_positions,
                       const PackedFloat32Array &ball_radii,
                       int resolution, double bounds_size, double threshold);

private:
    static float _eval_field(const Vector3 &p,
                             const Vector3 *balls, const float *radii, int count);
    static Vector3 _compute_normal(const Vector3 &p,
                                   const Vector3 *balls, const float *radii, int count);

    // Marching cubes tables (static, shared across instances)
    static const int EDGE_TABLE[256];
    static const int TRI_TABLE[256][16];
};

#endif // GN_NATIVE_METABALL_H
