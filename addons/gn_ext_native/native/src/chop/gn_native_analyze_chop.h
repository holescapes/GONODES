#ifndef GN_NATIVE_ANALYZE_CHOP_H
#define GN_NATIVE_ANALYZE_CHOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
namespace godot {
class GNNativeAnalyzeChop : public RefCounted {
    GDCLASS(GNNativeAnalyzeChop, RefCounted)
public:
    Dictionary process(const Dictionary &channels, int function);
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
