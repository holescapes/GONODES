#ifndef GN_NATIVE_SOP_TO_CHOP_H
#define GN_NATIVE_SOP_TO_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// Extracts vertex positions/normals/UVs to CHOP channels.
class GNNativeSopToChop : public RefCounted {
    GDCLASS(GNNativeSopToChop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// attrib_type: 0=Position, 1=Normal, 2=UV
    /// Returns Dictionary of channels (px/py/pz or nx/ny/nz or u/v).
    Dictionary process_positions(const PackedVector3Array &positions, int max_points);
    Dictionary process_normals(const PackedVector3Array &normals, int max_points);
    Dictionary process_uvs(const PackedFloat32Array &uvs_flat, int max_points);
};

} // namespace godot

#endif // GN_NATIVE_SOP_TO_CHOP_H
