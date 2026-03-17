#ifndef GN_NATIVE_POLYSTITCH_SOP_H
#define GN_NATIVE_POLYSTITCH_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// Stitches two point sets by connecting nearest vertex pairs.
class GNNativePolyStitchSop : public RefCounted {
    GDCLASS(GNNativePolyStitchSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns Dictionary {"positions": PV3A, "normals": PV3A, "indices": PI32A}.
    Dictionary process(const PackedVector3Array &pts_a,
                       const PackedVector3Array &pts_b,
                       double max_distance);
};

} // namespace godot

#endif // GN_NATIVE_POLYSTITCH_SOP_H
