#ifndef GN_NATIVE_AUDIO_GATE_CHOP_H
#define GN_NATIVE_AUDIO_GATE_CHOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
namespace godot {
class GNNativeAudioGateChop : public RefCounted {
    GDCLASS(GNNativeAudioGateChop, RefCounted)
    double _env[2] = {};
    bool _gate_open[2] = {};
public:
    PackedFloat32Array process(const PackedFloat32Array &input, double threshold,
                                double attack, double release, double range_db,
                                double hold_time, double sr);
    void reset();
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
