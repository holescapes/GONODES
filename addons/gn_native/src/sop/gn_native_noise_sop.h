#ifndef GN_NATIVE_NOISE_SOP_H
#define GN_NATIVE_NOISE_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// Displaces vertex positions using 3D noise (value/simplex/cellular).
class GNNativeNoiseSop : public RefCounted {
    GDCLASS(GNNativeNoiseSop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// axis_mode: 0=Normal, 1=X, 2=Y, 3=Z
    PackedVector3Array process(const PackedVector3Array &positions,
                               const PackedVector3Array &normals,
                               double amplitude, double frequency,
                               double offset_x, double offset_y, double offset_z,
                               double time_offset, int axis_mode, int seed);
};

} // namespace godot

#endif // GN_NATIVE_NOISE_SOP_H
