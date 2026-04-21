#ifndef GN_NATIVE_AUDIO_ENVELOPE_CHOP_H
#define GN_NATIVE_AUDIO_ENVELOPE_CHOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
namespace godot {
class GNNativeAudioEnvelopeChop : public RefCounted {
    GDCLASS(GNNativeAudioEnvelopeChop, RefCounted)
    double _env[2] = {};
public:
    PackedFloat32Array process(const PackedFloat32Array &input, double attack,
                                double release, double sr);
    void reset();
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
