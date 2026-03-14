#ifndef GN_NATIVE_BEND_SOP_H
#define GN_NATIVE_BEND_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

class GNNativeBendSop : public RefCounted {
    GDCLASS(GNNativeBendSop, RefCounted)
protected:
    static void _bind_methods();
public:
    /// Bends geometry around an axis. axis: 0=X, 1=Y, 2=Z. angle in radians.
    PackedVector3Array process(const PackedVector3Array &positions,
                               double angle_rad, int axis_idx,
                               double min_extent, double max_extent);
};

} // namespace godot
#endif
