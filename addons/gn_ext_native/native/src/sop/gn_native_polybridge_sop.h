#ifndef GN_NATIVE_POLYBRIDGE_SOP_H
#define GN_NATIVE_POLYBRIDGE_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

/// Bridge two edge loops with connecting geometry.
class GNNativePolyBridgeSop : public RefCounted {
    GDCLASS(GNNativePolyBridgeSop, RefCounted)

public:
    /// Bridge two loops. Returns Dictionary: "vertices", "normals", "uvs", "indices".
    Dictionary process(const PackedVector3Array &p_loop_a,
                       const PackedVector3Array &p_loop_b,
                       int p_divisions, double p_twist_deg) const;

protected:
    static void _bind_methods();
};

} // namespace godot

#endif
