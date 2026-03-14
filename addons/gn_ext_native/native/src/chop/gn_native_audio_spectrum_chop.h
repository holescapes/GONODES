#ifndef GN_NATIVE_AUDIO_SPECTRUM_CHOP_H
#define GN_NATIVE_AUDIO_SPECTRUM_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Real-valued DFT magnitude spectrum for audio CHOP data.
/// Computes N/2+1 magnitude bins from N input samples.
class GNNativeAudioSpectrumChop : public RefCounted {
    GDCLASS(GNNativeAudioSpectrumChop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Computes magnitude spectrum of input samples.
    /// Returns N/2+1 magnitude values.
    /// window_type: 0=None, 1=Hann, 2=Hamming
    PackedFloat32Array process(const PackedFloat32Array &samples, int window_type,
                               bool normalize);
};

} // namespace godot

#endif // GN_NATIVE_AUDIO_SPECTRUM_CHOP_H
