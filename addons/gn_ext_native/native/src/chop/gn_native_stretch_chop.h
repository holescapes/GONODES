#ifndef GN_NATIVE_STRETCH_CHOP_H
#define GN_NATIVE_STRETCH_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Resamples channels to a new length using linear, cubic, or nearest interpolation.
class GNNativeStretchChop : public RefCounted {
    GDCLASS(GNNativeStretchChop, RefCounted)

protected:
    static void _bind_methods();

public:
    Dictionary process(const Dictionary &in_channels, int new_length,
                       int interpolation);

private:
    static float _catmull_rom(float p0, float p1, float p2, float p3, float t);
};

} // namespace godot

#endif
