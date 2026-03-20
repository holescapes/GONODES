#ifndef GN_NATIVE_TRANSFORM_CHOP_H
#define GN_NATIVE_TRANSFORM_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Per-sample TRS transform applied to xyz channel triples.
class GNNativeTransformChop : public RefCounted {
    GDCLASS(GNNativeTransformChop, RefCounted)

public:
    /// Apply translate/rotate/scale to packed xyz samples.
    /// p_data: interleaved [x0,y0,z0, x1,y1,z1, ...] or per-channel flat layout.
    /// Returns transformed array same layout.
    PackedFloat32Array process(const PackedFloat32Array &p_data,
                                int p_num_samples,
                                double p_tx, double p_ty, double p_tz,
                                double p_rx, double p_ry, double p_rz,
                                double p_sx, double p_sy, double p_sz) const;

protected:
    static void _bind_methods();
};

} // namespace godot

#endif
