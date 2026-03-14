#ifndef GN_NATIVE_SWEEP_SOP_H
#define GN_NATIVE_SWEEP_SOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
namespace godot {
/// Sweeps a cross-section profile along a path backbone.
class GNNativeSweepSop : public RefCounted {
    GDCLASS(GNNativeSweepSop, RefCounted)
protected:
    static void _bind_methods();
public:
    /// Returns {"positions": PV3A, "normals": PV3A, "uvs": PV2A, "indices": PI32A}
    Dictionary process(const PackedVector3Array &profile_verts,
                       const PackedVector3Array &backbone_verts,
                       double scale, bool close_profile, bool close_backbone);
};
} // namespace godot
#endif
