#ifndef GN_NATIVE_FUSE_H
#define GN_NATIVE_FUSE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace godot {

/// Spatial-hash–based vertex fusing (merging coincident vertices).
/// O(N) average, O(N²) worst-case due to 27-cell neighbourhood search.
class GNNativeFuse : public RefCounted {
    GDCLASS(GNNativeFuse, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns Dictionary { "positions": PV3A, "uvs": PV2A, "indices": PI32A }
    Dictionary process(const PackedVector3Array &positions,
                       const PackedVector3Array &normals,
                       const PackedVector2Array &uvs,
                       const PackedInt32Array &indices,
                       double threshold);
};

} // namespace godot

#endif // GN_NATIVE_FUSE_H
