#ifndef GN_NATIVE_INTERPOLATE_CHOP_H
#define GN_NATIVE_INTERPOLATE_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Interpolates between two sets of CHOP channels.
/// method: 0=Linear, 1=Ease In, 2=Ease Out, 3=Smooth Step
class GNNativeInterpolateChop : public RefCounted {
    GDCLASS(GNNativeInterpolateChop, RefCounted)

protected:
    static void _bind_methods();

public:
    Dictionary process(const Dictionary &channels_a,
                       const Dictionary &channels_b,
                       double blend, int method);
};

} // namespace godot

#endif // GN_NATIVE_INTERPOLATE_CHOP_H
