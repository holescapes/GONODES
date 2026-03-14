#ifndef GN_NATIVE_MARCHING_CUBES_VOL_H
#define GN_NATIVE_MARCHING_CUBES_VOL_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

/// Extracts an iso-surface from a 3D scalar field via marching cubes.
/// Returns {"positions": PV3A, "normals": PV3A}.
class GNNativeMarchingCubesVol : public RefCounted {
    GDCLASS(GNNativeMarchingCubesVol, RefCounted)

protected:
    static void _bind_methods();

public:
    Dictionary process(const PackedFloat32Array &field,
                       int gx, int gy, int gz,
                       const Vector3 &origin, const Vector3 &cell_size,
                       double threshold, bool smooth_normals);

private:
    void _march_cell(int ix, int iy, int iz, int gx, int gy,
                     const float *field, float threshold,
                     const Vector3 &origin, const Vector3 &cell_size,
                     bool smooth, PackedVector3Array &out_verts,
                     PackedVector3Array &out_normals);

    Vector3 _gradient_normal(const Vector3 &p, const Vector3 &origin,
                             const Vector3 &cell, const float *field,
                             int gx, int gy, int gz);

    static const int _edge_table[256];
    static const int _tri_table[256][16];
};

} // namespace godot

#endif
