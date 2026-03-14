#ifndef GN_NATIVE_LOOKUP_CHOP_H
#define GN_NATIVE_LOOKUP_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

namespace godot {

/// Uses one channel's values to index into another channel's sample array.
class GNNativeLookupChop : public RefCounted {
    GDCLASS(GNNativeLookupChop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// interp: 0=linear, 1=nearest. extend: 0=clamp, 1=cycle, 2=mirror.
    Dictionary process(const Dictionary &table_channels,
                       const Dictionary &index_channels,
                       const PackedStringArray &index_ch_names,
                       int interpolation, int extend_mode);
};

} // namespace godot

#endif
