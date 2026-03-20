#ifndef GN_NATIVE_POLYSPLINE_SOP_H
#define GN_NATIVE_POLYSPLINE_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

/// Catmull-Rom spline + optional tube mesh.
class GNNativePolySplineSop : public RefCounted {
    GDCLASS(GNNativePolySplineSop, RefCounted)

public:
    /// Evaluate Catmull-Rom spline through control points.
    PackedVector3Array eval_spline(const PackedVector3Array &p_points,
                                    int p_subdivisions, bool p_closed) const;

    /// Build tube mesh around spline. Returns Dictionary: "vertices", "normals", "uvs", "indices".
    Dictionary build_tube(const PackedVector3Array &p_spine,
                          double p_radius, int p_sides, bool p_closed) const;

protected:
    static void _bind_methods();
};

} // namespace godot

#endif
