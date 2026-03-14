#ifndef GN_NATIVE_MOUNTAIN_SOP_H
#define GN_NATIVE_MOUNTAIN_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// Fractal noise displacement along normals (mountain/terrain effect).
class GNNativeMountainSop : public RefCounted {
    GDCLASS(GNNativeMountainSop, RefCounted)

protected:
    static void _bind_methods();

public:
    PackedVector3Array process(const PackedVector3Array &positions,
                               const PackedVector3Array &normals,
                               double height, double frequency, int octaves,
                               double roughness, int seed);
};

} // namespace godot

#endif
