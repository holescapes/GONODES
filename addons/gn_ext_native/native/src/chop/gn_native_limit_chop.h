#ifndef GN_NATIVE_LIMIT_CHOP_H
#define GN_NATIVE_LIMIT_CHOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
namespace godot {
class GNNativeLimitChop : public RefCounted {
    GDCLASS(GNNativeLimitChop, RefCounted)
public:
    Dictionary process(const Dictionary &channels, int type, double lo, double hi);
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
