#ifndef GN_NATIVE_NOISE_VOL_H
#define GN_NATIVE_NOISE_VOL_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Generates a 3D FBM noise volume (CPU path).
class GNNativeNoiseVol : public RefCounted {
    GDCLASS(GNNativeNoiseVol, RefCounted)

protected:
    static void _bind_methods();

public:
    PackedFloat32Array process(int res_x, int res_y, int res_z,
                               double frequency, double amplitude,
                               double offset_x, double offset_y, double offset_z,
                               double time_val, double lacunarity, double gain,
                               int octaves, int seed);
};

} // namespace godot

#endif // GN_NATIVE_NOISE_VOL_H
