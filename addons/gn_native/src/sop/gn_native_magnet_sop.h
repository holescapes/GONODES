#ifndef GN_NATIVE_MAGNET_SOP_H
#define GN_NATIVE_MAGNET_SOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
namespace godot {
/// Deforms geometry by pulling vertices toward a magnet point with falloff.
class GNNativeMagnetSop : public RefCounted {
    GDCLASS(GNNativeMagnetSop, RefCounted)
protected:
    static void _bind_methods();
public:
    PackedVector3Array process(const PackedVector3Array &positions,
                               const Vector3 &magnet_pos, double radius,
                               double strength, int falloff_type);
};
} // namespace godot
#endif
