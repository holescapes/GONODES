#ifndef GN_NATIVE_NOISE_CHOP_H
#define GN_NATIVE_NOISE_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// 1D hash-based smooth noise generator for CHOP channels.
/// Stateless — each call produces noise value(s) based on time input.
class GNNativeNoiseChop : public RefCounted {
    GDCLASS(GNNativeNoiseChop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Generates noise values for num_channels at given time.
    /// Returns Dictionary { channel_name -> PackedFloat32Array (single sample) }
    Dictionary process(int num_channels, double time_accum, double period,
                       double roughness, int seed);
};

} // namespace godot

#endif // GN_NATIVE_NOISE_CHOP_H
