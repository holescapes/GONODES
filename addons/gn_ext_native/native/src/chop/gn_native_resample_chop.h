#ifndef GN_NATIVE_RESAMPLE_CHOP_H
#define GN_NATIVE_RESAMPLE_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Resamples CHOP channels to a new sample count with interpolation.
/// quality: 0=Linear, 1=Cubic (Catmull-Rom), 2=Nearest
class GNNativeResampleChop : public RefCounted {
    GDCLASS(GNNativeResampleChop, RefCounted)

protected:
    static void _bind_methods();

public:
    Dictionary process(const Dictionary &channels, int target_samples, int quality);
};

} // namespace godot

#endif // GN_NATIVE_RESAMPLE_CHOP_H
