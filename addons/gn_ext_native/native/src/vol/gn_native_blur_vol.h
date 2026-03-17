#ifndef GN_NATIVE_BLUR_VOL_H
#define GN_NATIVE_BLUR_VOL_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/vector3i.hpp>

namespace godot {

/// 3D multi-pass box blur on a flat volume array.
class GNNativeBlurVol : public RefCounted {
    GDCLASS(GNNativeBlurVol, RefCounted)

protected:
    static void _bind_methods();

public:
    PackedFloat32Array process(const PackedFloat32Array &field,
                               int res_x, int res_y, int res_z,
                               int channels, int radius, int passes);
};

} // namespace godot

#endif // GN_NATIVE_BLUR_VOL_H
