#ifndef GN_NATIVE_ANALYZE_VOL_H
#define GN_NATIVE_ANALYZE_VOL_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Computes statistics over a 3D float field: min, max, mean, sum, nonzero count.
class GNNativeAnalyzeVol : public RefCounted {
    GDCLASS(GNNativeAnalyzeVol, RefCounted)

protected:
    static void _bind_methods();

public:
    Dictionary process(const PackedFloat32Array &field,
                       bool do_histogram, int hist_bins);
};

} // namespace godot

#endif
