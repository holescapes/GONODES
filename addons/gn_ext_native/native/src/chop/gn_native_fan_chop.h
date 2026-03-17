#ifndef GN_NATIVE_FAN_CHOP_H
#define GN_NATIVE_FAN_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

/// Fans a single channel into multiple copies with offset spread.
class GNNativeFanChop : public RefCounted {
    GDCLASS(GNNativeFanChop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// op: 0=Add, 1=Multiply, 2=Phase Shift
    Dictionary process(const PackedFloat32Array &src_samples,
                       int count, double offset, int op,
                       const String &prefix);
};

} // namespace godot

#endif // GN_NATIVE_FAN_CHOP_H
