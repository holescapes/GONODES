#ifndef GN_NATIVE_ADVECT_POP_H
#define GN_NATIVE_ADVECT_POP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// Advects particles through a 3D velocity volume field (CPU path).
class GNNativeAdvectPop : public RefCounted {
    GDCLASS(GNNativeAdvectPop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Modifies velocities from volume field. Returns updated velocities.
    PackedVector3Array process(const PackedVector3Array &positions,
                               const PackedVector3Array &velocities,
                               const PackedFloat32Array &vol_data,
                               int vol_rx, int vol_ry, int vol_rz,
                               int vol_ch,
                               double bounds_x, double bounds_y, double bounds_z,
                               double bounds_sx, double bounds_sy, double bounds_sz,
                               double strength, double dt, bool add_mode);
};

} // namespace godot

#endif // GN_NATIVE_ADVECT_POP_H
