#ifndef GN_NATIVE_WAVE_CHOP_H
#define GN_NATIVE_WAVE_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Waveform generator (sine, triangle, square, sawtooth, pulse, ramp).
class GNNativeWaveChop : public RefCounted {
    GDCLASS(GNNativeWaveChop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// wave_type: 0=sine,1=triangle,2=square,3=saw,4=pulse,5=ramp
    /// Returns Dictionary { channel_name -> PackedFloat32Array }
    Dictionary process(int wave_type, int num_channels, int sample_length,
                       double frequency, double amplitude, double offset,
                       double phase, double phase_step, double elapsed_time);
};

} // namespace godot

#endif // GN_NATIVE_WAVE_CHOP_H
