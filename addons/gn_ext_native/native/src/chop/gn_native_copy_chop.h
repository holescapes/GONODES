#ifndef GN_NATIVE_COPY_CHOP_H
#define GN_NATIVE_COPY_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

class GNNativeCopyChop : public RefCounted {
    GDCLASS(GNNativeCopyChop, RefCounted)

public:
    // Combines matching channels from A and B using the given operation.
    // op: 0=Overwrite, 1=Add, 2=Subtract, 3=Multiply
    // Returns dictionary of channel_name -> PackedFloat32Array
    Dictionary process(const Dictionary &channels_a, const Dictionary &channels_b,
                       int operation);

protected:
    static void _bind_methods();
};

} // namespace godot

#endif
