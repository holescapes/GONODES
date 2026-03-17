#ifndef GN_NATIVE_IK_CHOP_H
#define GN_NATIVE_IK_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

/// FABRIK inverse kinematics solver for joint chains.
class GNNativeIkChop : public RefCounted {
    GDCLASS(GNNativeIkChop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Returns Dictionary of channels: jN_tx, jN_ty, jN_tz, jN_rx, jN_ry.
    Dictionary process(int num_joints, double bone_length,
                       double target_x, double target_y, double target_z,
                       int iterations, bool constrain_y);
};

} // namespace godot

#endif // GN_NATIVE_IK_CHOP_H
