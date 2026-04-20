#ifndef DEPTH_SENSOR_BACKEND_H
#define DEPTH_SENSOR_BACKEND_H

// Shared depth sensor backend interface — used by all per-backend DLLs.
// Contains the abstract backend class, data structs, and capability flags.
// No Godot dependencies — pure C++.

#include <memory>
#include <string>
#include <vector>
#include <cstdint>

// ═══════════════════════════════════════════════════════════════════════════════
// Capability flags — bitfield indicating what a sensor backend can provide
// ═══════════════════════════════════════════════════════════════════════════════

enum DepthSensorCapability : uint32_t {
    CAP_NONE         = 0,
    CAP_DEPTH        = 1 << 0,
    CAP_COLOR        = 1 << 1,
    CAP_IR           = 1 << 2,
    CAP_SKELETON     = 1 << 3,
    CAP_POINT_CLOUD  = 1 << 4,
    CAP_PLAYER_INDEX = 1 << 5,
    CAP_FLOOR_PLANE  = 1 << 6,
    CAP_HAND_TRACK   = 1 << 7,
};

// ═══════════════════════════════════════════════════════════════════════════════
// Joint data — one entry per tracked joint, per body
// ═══════════════════════════════════════════════════════════════════════════════

struct DepthSensorJoint {
    float x, y, z;
    float qx, qy, qz, qw;
    float confidence;
    int   joint_id;
};

struct DepthSensorBody {
    int body_id;
    std::vector<DepthSensorJoint> joints;
};

// ═══════════════════════════════════════════════════════════════════════════════
// Hand data — one entry per finger bone, per hand
// ═══════════════════════════════════════════════════════════════════════════════

struct DepthSensorFinger {
    DepthSensorJoint bones[5];  // [0]=metacarpal .. [3]=distal, [4]=tip
};

struct DepthSensorHand {
    int hand_id;
    bool is_left;
    float confidence;
    float grab_strength;
    float pinch_strength;
    DepthSensorJoint palm;
    DepthSensorJoint wrist;
    DepthSensorFinger fingers[5]; // thumb, index, middle, ring, pinky
};

// ═══════════════════════════════════════════════════════════════════════════════
// Backend interface — implemented per SDK (Kinect, RealSense, Ultraleap)
// ═══════════════════════════════════════════════════════════════════════════════

class DepthSensorBackend {
public:
    virtual ~DepthSensorBackend() = default;

    virtual std::string get_backend_name() const = 0;
    virtual uint32_t get_capabilities() const = 0;

    struct DeviceInfo {
        std::string serial;
        std::string display_name;
    };
    virtual std::vector<DeviceInfo> enumerate_devices() = 0;

    virtual bool open(const std::string &serial) = 0;
    virtual void close() = 0;
    virtual bool is_open() const = 0;
    virtual bool capture(int timeout_ms) = 0;

    // Stream accessors
    virtual void get_depth_image(std::vector<uint8_t> &out, int &width, int &height) = 0;
    virtual void get_color_image(std::vector<uint8_t> &out, int &width, int &height) = 0;
    virtual void get_ir_image(std::vector<uint8_t> &out, int &width, int &height) = 0;
    virtual void get_player_index_image(std::vector<uint8_t> &out, int &width, int &height) = 0;
    virtual void get_bodies(std::vector<DepthSensorBody> &out) = 0;
    virtual void get_point_cloud(std::vector<float> &out) = 0;
    virtual void get_point_cloud_colors(std::vector<uint8_t> &out) = 0;
    virtual bool get_floor_plane(float &nx, float &ny, float &nz, float &d) = 0;
    virtual void get_hands(std::vector<DepthSensorHand> &out) = 0;

    static std::string get_finger_bone_name(int finger, int bone) {
        static const char *FINGER_NAMES[] = {"thumb", "index", "middle", "ring", "pinky"};
        static const char *BONE_NAMES[] = {"metacarpal", "proximal", "intermediate", "distal", "tip"};
        if (finger < 0 || finger > 4 || bone < 0 || bone > 4) return "unknown";
        return std::string(FINGER_NAMES[finger]) + "_" + BONE_NAMES[bone];
    }

    virtual std::string get_joint_name(int joint_id) const = 0;
    virtual int get_joint_count() const = 0;
};

#endif // DEPTH_SENSOR_BACKEND_H
