#ifndef GN_NATIVE_ANALYZE_TOP_H
#define GN_NATIVE_ANALYZE_TOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

class GNNativeAnalyzeTop : public RefCounted {
    GDCLASS(GNNativeAnalyzeTop, RefCounted)

protected:
    static void _bind_methods();

public:
    // mode: 0=Min, 1=Max, 2=Average, 3=Sum
    // Returns Dictionary with "r","g","b","a" float values + "image" (solid-color result)
    Dictionary process(const Ref<Image> &source, int mode, int kernel_size);
};

} // namespace godot

#endif // GN_NATIVE_ANALYZE_TOP_H
