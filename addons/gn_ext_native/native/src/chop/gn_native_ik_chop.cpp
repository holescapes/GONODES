#include "gn_native_ik_chop.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <cmath>
#include <vector>

namespace godot {

void GNNativeIkChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "num_joints", "bone_length",
                                  "target_x", "target_y", "target_z",
                                  "iterations", "constrain_y"),
                         &GNNativeIkChop::process);
}

static constexpr double TOLERANCE = 0.001;

Dictionary GNNativeIkChop::process(int num_joints, double bone_length,
                                    double target_x, double target_y,
                                    double target_z, int iterations,
                                    bool constrain_y) {
    Dictionary out;
    if (num_joints < 2) num_joints = 2;

    Vector3 target(target_x, target_y, target_z);

    // Initialize chain along +X
    std::vector<Vector3> joints(num_joints);
    for (int i = 0; i < num_joints; ++i)
        joints[i] = Vector3(i * bone_length, 0.0, 0.0);

    // Bone lengths
    std::vector<double> lengths(num_joints - 1, bone_length);

    double total_reach = 0.0;
    for (double l : lengths) total_reach += l;
    double dist = joints[0].distance_to(target);

    if (dist > total_reach) {
        // Unreachable — stretch toward target
        Vector3 dir = (target - joints[0]).normalized();
        for (int i = 1; i < num_joints; ++i)
            joints[i] = joints[i - 1] + dir * lengths[i - 1];
    } else {
        // FABRIK solver
        Vector3 root_pos = joints[0];
        for (int iter = 0; iter < iterations; ++iter) {
            // Forward pass
            joints[num_joints - 1] = target;
            for (int i = num_joints - 2; i >= 0; --i) {
                Vector3 dir = (joints[i] - joints[i + 1]).normalized();
                if (dir.length_squared() < 1e-10) dir = Vector3(0, 1, 0);
                joints[i] = joints[i + 1] + dir * lengths[i];
            }
            // Backward pass
            joints[0] = root_pos;
            for (int i = 1; i < num_joints; ++i) {
                Vector3 dir = (joints[i] - joints[i - 1]).normalized();
                if (dir.length_squared() < 1e-10) dir = Vector3(1, 0, 0);
                joints[i] = joints[i - 1] + dir * lengths[i - 1];
            }
            if (joints[num_joints - 1].distance_to(target) < TOLERANCE)
                break;
        }
    }

    // Apply Y constraint (flatten to XZ plane)
    if (constrain_y) {
        for (int i = 0; i < num_joints; ++i)
            joints[i].z = 0.0;
        for (int i = 1; i < num_joints; ++i) {
            Vector3 dir = (joints[i] - joints[i - 1]).normalized();
            if (dir.length_squared() < 1e-10) dir = Vector3(1, 0, 0);
            joints[i] = joints[i - 1] + dir * lengths[i - 1];
        }
    }

    // Output channels
    for (int i = 0; i < num_joints; ++i) {
        String prefix = "j" + String::num_int64(i) + "_";
        PackedFloat32Array tx, ty, tz;
        tx.resize(1); ty.resize(1); tz.resize(1);
        tx.ptrw()[0] = (float)joints[i].x;
        ty.ptrw()[0] = (float)joints[i].y;
        tz.ptrw()[0] = (float)joints[i].z;
        out[prefix + "tx"] = tx;
        out[prefix + "ty"] = ty;
        out[prefix + "tz"] = tz;

        if (i < num_joints - 1) {
            Vector3 bone_dir = (joints[i + 1] - joints[i]).normalized();
            double rx = std::atan2(bone_dir.y, bone_dir.z);
            double ry = std::atan2(bone_dir.x, bone_dir.z);
            PackedFloat32Array rxc, ryc;
            rxc.resize(1); ryc.resize(1);
            rxc.ptrw()[0] = (float)(rx * 180.0 / Math_PI);
            ryc.ptrw()[0] = (float)(ry * 180.0 / Math_PI);
            out[prefix + "rx"] = rxc;
            out[prefix + "ry"] = ryc;
        }
    }

    return out;
}

} // namespace godot
