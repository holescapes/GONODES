#ifndef GN_NATIVE_AUDIO_REVERB_CHOP_H
#define GN_NATIVE_AUDIO_REVERB_CHOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <vector>
namespace godot {
class GNNativeAudioReverbChop : public RefCounted {
    GDCLASS(GNNativeAudioReverbChop, RefCounted)
    static const int NUM_COMBS = 4;
    static const int NUM_APS = 2;
    std::vector<float> _comb_buf[NUM_COMBS][2];
    int _comb_idx[NUM_COMBS][2] = {};
    std::vector<float> _ap_buf[NUM_APS][2];
    int _ap_idx[NUM_APS][2] = {};
    bool _initialized = false;
    double _last_sr = 0.0;
public:
    PackedFloat32Array process(const PackedFloat32Array &input, double room_size,
                                double damping, double wet, double dry, double sr);
    void reset();
protected:
    static void _bind_methods();
private:
    void _init_buffers(double sr);
};
} // namespace godot
#endif
