#ifndef GN_NATIVE_LAG_CHOP_H
#define GN_NATIVE_LAG_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Exponential smoothing with separate attack/release rates (stateful).
class GNNativeLagChop : public RefCounted {
    GDCLASS(GNNativeLagChop, RefCounted)

    PackedFloat32Array _prev;

public:
    /// Process samples with lag. attack/release in seconds.
    PackedFloat32Array process(const PackedFloat32Array &p_data,
                                double p_attack, double p_release,
                                double p_dt);

    void reset();

protected:
    static void _bind_methods();
};

} // namespace godot

#endif
