#ifndef GN_NATIVE_AREA_CHOP_H
#define GN_NATIVE_AREA_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

class GNNativeAreaChop : public RefCounted {
    GDCLASS(GNNativeAreaChop, RefCounted)

public:
    Dictionary process(const Dictionary &channels, int method, bool cumulative, double dt);

protected:
    static void _bind_methods();
};

} // namespace godot

#endif
