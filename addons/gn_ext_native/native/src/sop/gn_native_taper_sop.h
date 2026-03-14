#ifndef GN_NATIVE_TAPER_SOP_H
#define GN_NATIVE_TAPER_SOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
namespace godot {
class GNNativeTaperSop : public RefCounted {
    GDCLASS(GNNativeTaperSop, RefCounted)
protected:
    static void _bind_methods();
public:
    /// Scales perpendicular axes based on position along taper axis.
    PackedVector3Array process(const PackedVector3Array &positions,
                               double taper_amount, int axis_idx,
                               double min_extent, double max_extent);
};
} // namespace godot
#endif
