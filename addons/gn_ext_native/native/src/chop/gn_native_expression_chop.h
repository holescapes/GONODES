#ifndef GN_NATIVE_EXPRESSION_CHOP_H
#define GN_NATIVE_EXPRESSION_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

/// Per-sample expression evaluator for CHOP channels.
class GNNativeExpressionChop : public RefCounted {
    GDCLASS(GNNativeExpressionChop, RefCounted)

protected:
    static void _bind_methods();

public:
    Dictionary process(const String &expr_str,
                       const Dictionary &in_channels,
                       const PackedStringArray &ch_names,
                       int base_length, double time_val, double delta);
};

} // namespace godot

#endif
