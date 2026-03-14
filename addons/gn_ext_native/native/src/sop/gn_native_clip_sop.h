#ifndef GN_NATIVE_CLIP_SOP_H
#define GN_NATIVE_CLIP_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace godot {

/// Clips triangle geometry against a plane, keeping one side and splitting
/// straddling triangles.  Returns new vertex/UV arrays.
class GNNativeClipSop : public RefCounted {
    GDCLASS(GNNativeClipSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns {"positions": PV3A, "uvs": PV2A}.
    Dictionary process(const PackedVector3Array &verts,
                       const PackedVector2Array &uvs,
                       const PackedInt32Array &indices,
                       const Vector3 &normal, double origin);
};

} // namespace godot

#endif
