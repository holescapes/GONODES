#ifndef GN_NATIVE_UV_PROJECT_SOP_H
#define GN_NATIVE_UV_PROJECT_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>

namespace godot {

/// Computes UV coordinates via planar, cylindrical, or spherical projection.
class GNNativeUvProjectSop : public RefCounted {
    GDCLASS(GNNativeUvProjectSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// mode: 0=planar, 1=cylindrical, 2=spherical. axis: 0=X, 1=Y, 2=Z.
    PackedVector2Array process(const PackedVector3Array &verts,
                               int mode, int axis,
                               double scale_u, double scale_v);
};

} // namespace godot

#endif
