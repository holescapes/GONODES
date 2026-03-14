#ifndef GN_NATIVE_EXTRUDE_SOP_H
#define GN_NATIVE_EXTRUDE_SOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
namespace godot {
/// Extrudes mesh faces along their normals.
class GNNativeExtrudeSop : public RefCounted {
    GDCLASS(GNNativeExtrudeSop, RefCounted)
protected:
    static void _bind_methods();
public:
    /// Returns {"positions": PV3A, "normals": PV3A, "indices": PI32A}
    Dictionary process(const PackedVector3Array &positions,
                       const PackedVector3Array &normals,
                       const PackedInt32Array &indices,
                       double distance, double inset);
};
} // namespace godot
#endif
