#ifndef GN_NATIVE_AUDIO_FILTER_CHOP_H
#define GN_NATIVE_AUDIO_FILTER_CHOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
namespace godot {
class GNNativeAudioFilterChop : public RefCounted {
    GDCLASS(GNNativeAudioFilterChop, RefCounted)
    double _x1[2]={}, _x2[2]={}, _y1[2]={}, _y2[2]={};
public:
    PackedFloat32Array process(const PackedFloat32Array &input, int type,
                                double cutoff, double q, double gain_db, double sr);
    void reset();
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
