#ifndef GN_NATIVE_PEAK_SOP_H
#define GN_NATIVE_PEAK_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// Offset vertices along normals by a uniform distance.
class GNNativePeakSop : public RefCounted {
    GDCLASS(GNNativePeakSop, RefCounted)

public:
    PackedVector3Array process(const PackedVector3Array &p_positions,
                                const PackedVector3Array &p_normals,
                                double p_distance) const;

protected:
    static void _bind_methods();
};

} // namespace godot

#endif
