#ifndef GN_NATIVE_CROSS_CHOP_H
#define GN_NATIVE_CROSS_CHOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
namespace godot {
class GNNativeCrossChop : public RefCounted {
    GDCLASS(GNNativeCrossChop, RefCounted)
public:
    Dictionary process(const Dictionary &a, const Dictionary &b, double cross);
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
