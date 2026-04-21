#ifndef GN_NATIVE_RESAMPLE_SOP_H
#define GN_NATIVE_RESAMPLE_SOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
namespace godot {
class GNNativeResampleSop : public RefCounted {
    GDCLASS(GNNativeResampleSop, RefCounted)
public:
    // Resample polyline to even spacing or target segment count
    PackedVector3Array process(const PackedVector3Array &points, int mode,
                                double segment_length, int segment_count, bool closed);
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
