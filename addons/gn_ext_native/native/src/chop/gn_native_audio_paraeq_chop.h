#ifndef GN_NATIVE_AUDIO_PARAEQ_CHOP_H
#define GN_NATIVE_AUDIO_PARAEQ_CHOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
namespace godot {
class GNNativeAudioParaEqChop : public RefCounted {
    GDCLASS(GNNativeAudioParaEqChop, RefCounted)
    static const int MAX_BANDS = 8;
    double _x1[MAX_BANDS][2]={}, _x2[MAX_BANDS][2]={};
    double _y1[MAX_BANDS][2]={}, _y2[MAX_BANDS][2]={};
public:
    PackedFloat32Array process(const PackedFloat32Array &input,
                                const PackedFloat32Array &freqs,
                                const PackedFloat32Array &gains,
                                const PackedFloat32Array &qs,
                                int num_bands, double sr);
    void reset();
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
