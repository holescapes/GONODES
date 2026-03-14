#ifndef GN_NATIVE_NORMAL_SOP_H
#define GN_NATIVE_NORMAL_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace godot {

/// Recomputes or flips vertex normals.
class GNNativeNormalSop : public RefCounted {
    GDCLASS(GNNativeNormalSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// mode: 0=smooth, 1=flip, 2=flat.
    /// Returns {"positions": PV3A, "normals": PV3A, "uvs": PV2A} (flat mode unshares verts).
    Dictionary process(const PackedVector3Array &verts,
                       const PackedVector3Array &normals,
                       const PackedVector2Array &uvs,
                       const PackedInt32Array &indices,
                       int mode);
};

} // namespace godot

#endif
