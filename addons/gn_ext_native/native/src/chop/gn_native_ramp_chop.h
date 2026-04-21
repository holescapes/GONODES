#ifndef GN_NATIVE_RAMP_CHOP_H
#define GN_NATIVE_RAMP_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

class GNNativeRampChop : public RefCounted {
    GDCLASS(GNNativeRampChop, RefCounted)

public:
    // Evaluates a cubic Hermite ramp at evenly-spaced sample positions.
    // key_positions, key_values, key_left_tangents, key_right_tangents: parallel arrays of ramp keypoints.
    // sample_count: number of evaluation points (1 = evaluate at t=1.0).
    PackedFloat32Array evaluate_ramp(const PackedFloat32Array &key_positions,
                                      const PackedFloat32Array &key_values,
                                      const PackedFloat32Array &key_left_tangents,
                                      const PackedFloat32Array &key_right_tangents,
                                      int sample_count);

protected:
    static void _bind_methods();
};

} // namespace godot

#endif
