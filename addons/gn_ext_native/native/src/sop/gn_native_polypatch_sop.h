#ifndef GN_NATIVE_POLYPATCH_SOP_H
#define GN_NATIVE_POLYPATCH_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

/// Bilinear Coons patch from 4 corners with grid subdivision.
class GNNativePolyPatchSop : public RefCounted {
    GDCLASS(GNNativePolyPatchSop, RefCounted)

public:
    /// Build patch mesh. Returns Dictionary with "vertices", "normals", "uvs", "indices".
    Dictionary process(const Vector3 &p_c00, const Vector3 &p_c10,
                       const Vector3 &p_c01, const Vector3 &p_c11,
                       int p_rows, int p_cols) const;

protected:
    static void _bind_methods();
};

} // namespace godot

#endif
