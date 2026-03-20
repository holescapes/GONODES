#ifndef GN_NATIVE_GROUP_SOP_H
#define GN_NATIVE_GROUP_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

/// Per-vertex/per-tri group classification.
class GNNativeGroupSop : public RefCounted {
    GDCLASS(GNNativeGroupSop, RefCounted)

public:
    /// Classify vertices by bounding box.
    PackedFloat32Array group_by_bbox(const PackedVector3Array &p_positions,
                                      const Vector3 &p_min, const Vector3 &p_max) const;

    /// Classify vertices by normal direction cone.
    PackedFloat32Array group_by_normal(const PackedVector3Array &p_normals,
                                        const Vector3 &p_direction,
                                        double p_angle_deg) const;

protected:
    static void _bind_methods();
};

} // namespace godot

#endif
