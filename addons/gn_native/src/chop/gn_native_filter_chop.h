#ifndef GN_NATIVE_FILTER_CHOP_H
#define GN_NATIVE_FILTER_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Single-pole IIR low-pass / high-pass filter for CHOP channels.
/// Maintains per-channel state across calls.
class GNNativeFilterChop : public RefCounted {
    GDCLASS(GNNativeFilterChop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// filter_type: 0=LP, 1=HP
    Dictionary process(const Dictionary &channels, int filter_type,
                       double cutoff, bool reset);
    void clear_state();

private:
    HashMap<String, double> _prev;
};

} // namespace godot

#endif // GN_NATIVE_FILTER_CHOP_H
