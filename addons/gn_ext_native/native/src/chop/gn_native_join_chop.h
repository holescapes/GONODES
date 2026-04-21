#ifndef GN_NATIVE_JOIN_CHOP_H
#define GN_NATIVE_JOIN_CHOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
namespace godot {
class GNNativeJoinChop : public RefCounted {
    GDCLASS(GNNativeJoinChop, RefCounted)
public:
    Dictionary process(const Dictionary &a, const Dictionary &b, int overlap);
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
