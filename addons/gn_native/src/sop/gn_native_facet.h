#ifndef GN_NATIVE_FACET_H
#define GN_NATIVE_FACET_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace godot {

/// Vertex consolidation (merge coincident vertices within a distance).
/// Uses spatial hashing for O(N) average case instead of O(N²).
class GNNativeFacet : public RefCounted {
    GDCLASS(GNNativeFacet, RefCounted)

protected:
    static void _bind_methods();

public:
    /// mode 0 = make unique (flat), mode 1 = consolidate (merge)
    /// Returns Dictionary { "positions": PV3A, "normals": PV3A, "uvs": PV2A, "indices": PI32A }
    Dictionary process(const PackedVector3Array &positions,
                       const PackedVector2Array &uvs,
                       const PackedInt32Array &indices,
                       int mode, double distance);
};

} // namespace godot

#endif // GN_NATIVE_FACET_H
