#ifndef GN_NATIVE_PATTERN_CHOP_H
#define GN_NATIVE_PATTERN_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Generates a pattern (ramp, step, pulse, zigzag) as multi-sample CHOP data.
class GNNativePatternChop : public RefCounted {
    GDCLASS(GNNativePatternChop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// pattern_type: 0=Ramp, 1=Step, 2=Pulse, 3=ZigZag, 4=Random
    PackedFloat32Array process(int pattern_type, int length, double param1,
                               double param2, int seed);
};

} // namespace godot

#endif // GN_NATIVE_PATTERN_CHOP_H
