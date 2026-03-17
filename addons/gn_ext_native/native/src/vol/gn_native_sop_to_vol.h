#ifndef GN_NATIVE_SOP_TO_VOL_H
#define GN_NATIVE_SOP_TO_VOL_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// Rasterizes SOP points into a density volume (smooth sphere splatting).
class GNNativeSopToVol : public RefCounted {
    GDCLASS(GNNativeSopToVol, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns Dictionary {"field": PF32A, "bmin_x/y/z": float, "bsize_x/y/z": float}.
    Dictionary process(const PackedVector3Array &positions,
                       int res_x, int res_y, int res_z,
                       double radius, double strength, double padding);
};

} // namespace godot

#endif // GN_NATIVE_SOP_TO_VOL_H
