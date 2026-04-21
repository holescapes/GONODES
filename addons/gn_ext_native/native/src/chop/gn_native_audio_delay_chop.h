#ifndef GN_NATIVE_AUDIO_DELAY_CHOP_H
#define GN_NATIVE_AUDIO_DELAY_CHOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <vector>
namespace godot {
class GNNativeAudioDelayChop : public RefCounted {
    GDCLASS(GNNativeAudioDelayChop, RefCounted)
    std::vector<float> _buf[2];
    int _write_idx[2] = {};
    bool _initialized = false;
    double _last_sr = 0.0;
    double _last_max_delay = 0.0;
public:
    PackedFloat32Array process(const PackedFloat32Array &input, double delay_time,
                                double feedback, double wet, double dry,
                                double max_delay, double sr);
    void reset();
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
