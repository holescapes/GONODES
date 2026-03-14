#ifndef GN_NATIVE_SLOPE_CHOP_H
#define GN_NATIVE_SLOPE_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Computes per-sample slope (derivative) of CHOP channels.
/// Maintains previous-frame value for frame-to-frame derivative.
class GNNativeSlopeChop : public RefCounted {
    GDCLASS(GNNativeSlopeChop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// method: 0=forward difference, 1=central difference
    Dictionary process(const Dictionary &channels, int method, double scale, bool reset);
    void clear_state();

private:
    HashMap<String, double> _prev_last;  // last sample of previous frame
};

} // namespace godot

#endif // GN_NATIVE_SLOPE_CHOP_H
