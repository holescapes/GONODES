#ifndef GN_NATIVE_CHOP_TO_TOP_H
#define GN_NATIVE_CHOP_TO_TOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/color.hpp>

namespace godot {

/// CPU-renders CHOP channels as waveform, heatmap, or graph into an Image.
class GNNativeChopToTop : public RefCounted {
    GDCLASS(GNNativeChopToTop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// mode: 0=waveform, 1=heatmap, 2=graph.
    Ref<Image> process(const Dictionary &channels,
                       const PackedStringArray &ch_names,
                       int mode, int width, int height,
                       const Color &bg, const Color &line_color,
                       double line_width, double min_val, double max_val);
};

} // namespace godot

#endif
