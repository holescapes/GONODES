#ifndef GN_NATIVE_ISOSURFACE_H
#define GN_NATIVE_ISOSURFACE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

/// Marching-cubes iso-surface extractor for analytic implicit fields.
/// Evaluates built-in surface types (Gyroid, Schwarz-P/D, Sphere, Torus)
/// on a voxel grid, then runs marching cubes to produce triangle soup.
class GNNativeIsoSurface : public RefCounted {
    GDCLASS(GNNativeIsoSurface, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns Dictionary { "positions": PV3A, "normals": PV3A }
    /// surface_type: 0=Gyroid,1=SchwarzP,2=SchwarzD,3=Sphere,4=Torus
    Dictionary process(int surface_type, int resolution, double bounds_size,
                       double threshold, double frequency,
                       double major_radius, double minor_radius);

private:
    float _eval_field(int stype, float x, float y, float z,
                      float freq, float major_r, float minor_r) const;
    Vector3 _gradient_normal(int stype, const Vector3 &p, float freq,
                             float major_r, float minor_r, float eps) const;

    static const int EDGE_TABLE[256];
    static const int TRI_TABLE[256][16];
    static bool _tables_copied;
    static void _ensure_tables();
};

} // namespace godot

#endif // GN_NATIVE_ISOSURFACE_H
