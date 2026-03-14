#ifndef GN_NATIVE_TOP_TO_CHOP_H
#define GN_NATIVE_TOP_TO_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

/// Samples pixel data from an Image into CHOP channel arrays.
class GNNativeTopToChop : public RefCounted {
    GDCLASS(GNNativeTopToChop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// mode: 0=average, 1=center pixel, 2=row average, 3=column average.
    Dictionary process(const Ref<Image> &img, int mode,
                       bool want_r, bool want_g, bool want_b, bool want_a);
};

} // namespace godot

#endif
