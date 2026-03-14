#ifndef GN_NATIVE_SMOOTH_H
#define GN_NATIVE_SMOOTH_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

namespace godot {

/// Biquad IIR (Butterworth) filter for CHOP channel data.
/// Maintains per-channel filter state across calls.
class GNNativeSmooth : public RefCounted {
    GDCLASS(GNNativeSmooth, RefCounted)

protected:
    static void _bind_methods();

public:
    GNNativeSmooth() = default;

    /// filter_type: 0=LP, 1=HP, 2=BP
    /// Returns Dictionary mapping channel name → filtered PackedFloat32Array
    Dictionary process(const Dictionary &channels, int filter_type,
                       double cutoff, double q, bool reset);

    void clear_state();

private:
    // Per-channel state: x[n-1], x[n-2], y[n-1], y[n-2]
    struct FilterState {
        double x1 = 0, x2 = 0, y1 = 0, y2 = 0;
    };
    HashMap<String, FilterState> _state;
};

} // namespace godot

#endif // GN_NATIVE_SMOOTH_H
