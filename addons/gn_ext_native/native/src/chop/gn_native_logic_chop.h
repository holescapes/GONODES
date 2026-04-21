#ifndef GN_NATIVE_LOGIC_CHOP_H
#define GN_NATIVE_LOGIC_CHOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
namespace godot {
class GNNativeLogicChop : public RefCounted {
    GDCLASS(GNNativeLogicChop, RefCounted)
public:
    Dictionary process(const Dictionary &a, const Dictionary &b, int operation, double threshold);
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
