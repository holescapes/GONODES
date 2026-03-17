#ifndef GN_NATIVE_LASER_CHOP_H
#define GN_NATIVE_LASER_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

/// Laser point-list generator with built-in patterns (Circle, Line, Square, Spiral, ILDA Test).
class GNNativeLaserChop : public RefCounted {
    GDCLASS(GNNativeLaserChop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// pattern: 0=Circle, 1=Line, 2=Square, 3=Spiral, 4=ILDA Test
    /// Returns Dictionary of channels: x, y, r, g, b, i.
    Dictionary process(int pattern, int num_points, double scale,
                       double rotation, double color_r, double color_g,
                       double color_b, double intensity,
                       int blank_points, double angle_accum);
};

} // namespace godot

#endif // GN_NATIVE_LASER_CHOP_H
