#ifndef GN_NATIVE_DISPLACE_VOL_H
#define GN_NATIVE_DISPLACE_VOL_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Displaces a density volume by a velocity field (CPU path).
class GNNativeDisplaceVol : public RefCounted {
    GDCLASS(GNNativeDisplaceVol, RefCounted)

protected:
    static void _bind_methods();

public:
    PackedFloat32Array process(const PackedFloat32Array &density,
                               const PackedFloat32Array &velocity,
                               int res_x, int res_y, int res_z,
                               int den_ch, int vel_ch, double strength);
};

} // namespace godot

#endif // GN_NATIVE_DISPLACE_VOL_H
