#ifndef GN_NATIVE_MATH_CHOP_H
#define GN_NATIVE_MATH_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Per-sample math operations on CHOP channels.
/// Operations: 0=Add,1=Sub,2=Mul,3=Div,4=Abs,5=Sin,6=Cos,7=Pow
class GNNativeMathChop : public RefCounted {
    GDCLASS(GNNativeMathChop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Binary: operates channel-wise between two channel dictionaries.
    Dictionary process_binary(const Dictionary &channels_a,
                              const Dictionary &channels_b,
                              int operation);

    /// Unary: operates on channels_a with a scalar operand.
    Dictionary process_unary(const Dictionary &channels_a,
                             int operation, double operand);
};

} // namespace godot

#endif // GN_NATIVE_MATH_CHOP_H
