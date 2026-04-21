#ifndef GN_NATIVE_AUDIO_OSCILLATOR_CHOP_H
#define GN_NATIVE_AUDIO_OSCILLATOR_CHOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
namespace godot {
class GNNativeAudioOscillatorChop : public RefCounted {
    GDCLASS(GNNativeAudioOscillatorChop, RefCounted)
    double _phase_l = 0.0, _phase_r = 0.0;
public:
    PackedFloat32Array process_stereo(int waveform, double freq, double amp,
                                       double pw, double fm_depth, double stereo_phase,
                                       int buffer_size, double sample_rate,
                                       const PackedFloat32Array &fm_input);
    void reset();
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
