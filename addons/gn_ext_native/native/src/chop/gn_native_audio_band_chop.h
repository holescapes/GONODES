#ifndef GN_NATIVE_AUDIO_BAND_CHOP_H
#define GN_NATIVE_AUDIO_BAND_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

namespace godot {

class GNNativeAudioBandChop : public RefCounted {
    GDCLASS(GNNativeAudioBandChop, RefCounted)

public:
    // Processes spectrum input bands into output frequency bands with envelope following.
    // input_bands: raw spectrum values for each input bin
    // envelopes: current envelope state (modified in-place)
    // peaks: current peak state (modified in-place)
    // crossovers: frequency edges between bands (num_bands + 1 values)
    // Returns Dictionary with keys: "levels", "peaks_out", "norms", "total", "dominant"
    Dictionary process(const PackedFloat32Array &input_bands,
                       const PackedFloat32Array &envelopes,
                       const PackedFloat32Array &peaks,
                       const PackedFloat32Array &crossovers,
                       int num_bands, double gain, double freq_min, double freq_max,
                       double att_coeff, double rel_coeff, double peak_decay);

protected:
    static void _bind_methods();
};

} // namespace godot

#endif
