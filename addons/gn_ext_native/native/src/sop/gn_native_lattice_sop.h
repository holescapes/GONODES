#ifndef GN_NATIVE_LATTICE_SOP_H
#define GN_NATIVE_LATTICE_SOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
namespace godot {
/// Deforms geometry using a 3D lattice of control points (FFD).
class GNNativeLatticeSop : public RefCounted {
    GDCLASS(GNNativeLatticeSop, RefCounted)
protected:
    static void _bind_methods();
public:
    /// lattice: control points in a flat array, dimensions sx×sy×sz
    PackedVector3Array process(const PackedVector3Array &positions,
                               const PackedVector3Array &lattice_points,
                               int sx, int sy, int sz,
                               const Vector3 &bbox_min, const Vector3 &bbox_max);
};
} // namespace godot
#endif
