#ifndef GN_NATIVE_AUDIO_PITCH_CHOP_H
#define GN_NATIVE_AUDIO_PITCH_CHOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <vector>
namespace godot {
class GNNativeAudioPitchChop : public RefCounted {
    GDCLASS(GNNativeAudioPitchChop, RefCounted)
    std::vector<float> _grain_buf[2];
    int _grain_pos[2] = {};
    bool _initialized = false;
    double _last_sr = 0.0;
public:
    PackedFloat32Array process(const PackedFloat32Array &input, double pitch_shift,
                                int grain_size, double sr);
    void reset();
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
