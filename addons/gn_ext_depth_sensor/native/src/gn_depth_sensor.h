#ifndef GN_DEPTH_SENSOR_H
#define GN_DEPTH_SENSOR_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/typed_array.hpp>

#include <memory>
#include <vector>
#include <string>

using namespace godot;

// ═══════════════════════════════════════════════════════════════════════════════
// Capability flags — bitfield indicating what a sensor backend can provide
// ═══════════════════════════════════════════════════════════════════════════════

enum DepthSensorCapability : uint32_t {
    CAP_NONE         = 0,
    CAP_DEPTH        = 1 << 0,   // Depth image (16-bit millimeters or float meters)
    CAP_COLOR        = 1 << 1,   // RGB/RGBA color image
    CAP_IR           = 1 << 2,   // Infrared image
    CAP_SKELETON     = 1 << 3,   // Hardware-accelerated body tracking (joints)
    CAP_POINT_CLOUD  = 1 << 4,   // Native 3D point cloud from depth
    CAP_PLAYER_INDEX = 1 << 5,   // Per-pixel body segmentation index
    CAP_FLOOR_PLANE  = 1 << 6,   // Detected floor plane (normal + distance)
    CAP_HAND_TRACK   = 1 << 7,   // Dedicated hand/finger tracking
};

// ═══════════════════════════════════════════════════════════════════════════════
// Joint data — one entry per tracked joint, per body
// ═══════════════════════════════════════════════════════════════════════════════

struct DepthSensorJoint {
    float x, y, z;         // Position in meters (sensor-local coordinates)
    float qx, qy, qz, qw; // Orientation quaternion
    float confidence;       // 0.0–1.0 tracking confidence
    int   joint_id;         // SDK-specific joint index
};

struct DepthSensorBody {
    int body_id;                         // Tracking ID (persistent across frames)
    std::vector<DepthSensorJoint> joints;
};

// ═══════════════════════════════════════════════════════════════════════════════
// Hand data — one entry per finger bone, per hand
// ═══════════════════════════════════════════════════════════════════════════════

struct DepthSensorFinger {
    // 4 bones per finger (metacarpal, proximal, intermediate, distal) + tip
    // Each has position in meters and orientation quaternion
    DepthSensorJoint bones[5];  // [0]=metacarpal .. [3]=distal, [4]=tip
};

struct DepthSensorHand {
    int hand_id;               // 0 = left, 1 = right
    bool is_left;              // true = left hand
    float confidence;          // Overall tracking confidence 0–1
    float grab_strength;       // 0 = open, 1 = full grab
    float pinch_strength;      // 0 = open, 1 = pinching
    DepthSensorJoint palm;     // Palm center position + orientation
    DepthSensorJoint wrist;    // Wrist position + orientation
    DepthSensorFinger fingers[5]; // thumb, index, middle, ring, pinky
};

// ═══════════════════════════════════════════════════════════════════════════════
// Backend interface — implemented per SDK (Kinect, RealSense, etc.)
// ═══════════════════════════════════════════════════════════════════════════════

class DepthSensorBackend {
public:
    virtual ~DepthSensorBackend() = default;

    /// Human-readable backend name (e.g. "Azure Kinect", "RealSense D400").
    virtual std::string get_backend_name() const = 0;

    /// Capability bitmask for this backend.
    virtual uint32_t get_capabilities() const = 0;

    /// Enumerate connected devices.  Returns list of {serial, name} pairs.
    struct DeviceInfo {
        std::string serial;
        std::string display_name;
    };
    virtual std::vector<DeviceInfo> enumerate_devices() = 0;

    /// Open a device by serial number.  Empty serial = first available.
    virtual bool open(const std::string &serial) = 0;

    /// Close the currently open device.
    virtual void close() = 0;

    /// Returns true if a device is currently open and streaming.
    virtual bool is_open() const = 0;

    /// Capture one frame from the sensor.  Call this once per cook frame.
    /// Returns true if new data is available.
    virtual bool capture(int timeout_ms) = 0;

    // ── Stream accessors (return empty if capability not supported) ────

    /// Depth image: 16-bit unsigned, millimeters.  Row-major, width × height × 2 bytes.
    virtual void get_depth_image(std::vector<uint8_t> &out, int &width, int &height) = 0;

    /// Color image: RGBA8.  Row-major, width × height × 4 bytes.
    virtual void get_color_image(std::vector<uint8_t> &out, int &width, int &height) = 0;

    /// IR image: 16-bit unsigned.  Row-major, width × height × 2 bytes.
    virtual void get_ir_image(std::vector<uint8_t> &out, int &width, int &height) = 0;

    /// Player/body index image: 8-bit per pixel (0 = background, 1+ = body ID).
    virtual void get_player_index_image(std::vector<uint8_t> &out, int &width, int &height) = 0;

    /// Tracked bodies with joint data.
    virtual void get_bodies(std::vector<DepthSensorBody> &out) = 0;

    /// 3D point cloud: packed float xyz triples (x, y, z, x, y, z, ...) in meters.
    virtual void get_point_cloud(std::vector<float> &out) = 0;

    /// Point cloud colors: packed RGBA8 per point (same count as point_cloud / 3).
    virtual void get_point_cloud_colors(std::vector<uint8_t> &out) = 0;

    /// Floor plane: returns true if detected.  Normal is (nx, ny, nz), d = distance from origin.
    virtual bool get_floor_plane(float &nx, float &ny, float &nz, float &d) = 0;

    // ── Hand tracking ─────────────────────────────────────────────────

    /// Tracked hands with per-finger bone data.
    virtual void get_hands(std::vector<DepthSensorHand> &out) = 0;

    /// Returns the canonical finger bone name for display.
    /// finger: 0=thumb, 1=index, 2=middle, 3=ring, 4=pinky
    /// bone: 0=metacarpal, 1=proximal, 2=intermediate, 3=distal, 4=tip
    static std::string get_finger_bone_name(int finger, int bone) {
        static const char *FINGER_NAMES[] = {"thumb", "index", "middle", "ring", "pinky"};
        static const char *BONE_NAMES[] = {"metacarpal", "proximal", "intermediate", "distal", "tip"};
        if (finger < 0 || finger > 4 || bone < 0 || bone > 4) return "unknown";
        return std::string(FINGER_NAMES[finger]) + "_" + BONE_NAMES[bone];
    }

    // ── Joint name mapping ────────────────────────────────────────────

    /// Returns the canonical joint name for a joint_id from this SDK.
    /// Used to normalize Azure Kinect / RealSense / etc. joint names to
    /// a common vocabulary (head, neck, spine_chest, left_shoulder, ...).
    virtual std::string get_joint_name(int joint_id) const = 0;

    /// Number of joints per body in this SDK's skeleton model.
    virtual int get_joint_count() const = 0;
};

// ═══════════════════════════════════════════════════════════════════════════════
// GNDepthSensor — Godot-facing RefCounted class
// ═══════════════════════════════════════════════════════════════════════════════

/// Unified depth sensor interface exposed to GDScript via ClassDB.
///
/// GDScript usage:
///   var sensor = ClassDB.instantiate("GNDepthSensor")
///   var devices = sensor.enumerate_devices()     # Array[Dictionary]
///   sensor.open_device(serial, "azure_kinect")   # or "realsense"
///   sensor.capture()
///   var depth = sensor.get_depth_rgba()           # PackedByteArray
///   var bodies = sensor.get_skeleton_data()       # Array[Dictionary]
///   sensor.close_device()
class GNDepthSensor : public RefCounted {
    GDCLASS(GNDepthSensor, RefCounted);

protected:
    static void _bind_methods();

public:
    GNDepthSensor();
    ~GNDepthSensor();

    // ── Backend / Device Management ──────────────────────────────────

    /// Returns list of available backend names: ["azure_kinect", "realsense", ...]
    PackedStringArray get_available_backends();

    /// Enumerate all connected depth sensors across all backends.
    /// Returns Array of Dictionaries: { "serial": String, "name": String, "backend": String }
    TypedArray<Dictionary> enumerate_devices();

    /// Open a device by serial number using the specified backend.
    /// [param serial]: Device serial (empty = first available for that backend).
    /// [param backend_name]: "azure_kinect", "realsense", etc.
    bool open_device(const String &serial, const String &backend_name);

    /// Close the currently open device.
    void close_device();

    /// Returns true if a device is open and streaming.
    bool is_device_open() const;

    /// Returns the capability bitmask for the active backend (or 0).
    int get_capabilities() const;

    /// Check if a specific capability is supported.
    bool has_capability(int cap) const;

    /// Returns the backend name of the currently open device.
    String get_active_backend() const;

    // ── Frame Capture ────────────────────────────────────────────────

    /// Capture a frame from the sensor.  Call once per cook.
    /// [param timeout_ms]: Max wait time in ms (0 = no wait).
    /// Returns true if new data was captured.
    bool capture(int timeout_ms = 33);

    // ── Image Streams ────────────────────────────────────────────────
    // All images returned as PackedByteArray for Image.create_from_data().

    /// Depth → RGBA8 visualization (near=white, far=dark; range normalized).
    /// [param max_mm]: Maximum depth in millimeters for normalization (default 5000).
    PackedByteArray get_depth_rgba(int max_mm = 5000);
    int get_depth_width() const;
    int get_depth_height() const;

    /// Raw depth as PackedByteArray (16-bit unsigned LE, millimeters).
    PackedByteArray get_depth_raw();

    /// Color camera image as RGBA8 PackedByteArray.
    PackedByteArray get_color_rgba();
    int get_color_width() const;
    int get_color_height() const;

    /// IR image → RGBA8 visualization (16-bit IR normalized to grayscale).
    PackedByteArray get_ir_rgba();
    int get_ir_width() const;
    int get_ir_height() const;

    /// Player/body index → RGBA8 with distinct colors per body ID.
    PackedByteArray get_player_index_rgba();

    // ── Skeleton ─────────────────────────────────────────────────────

    /// Returns skeleton data as Array of body Dictionaries:
    /// [{ "body_id": int, "joints": [{ "name": String, "x": float, "y": float,
    ///    "z": float, "qx": float, "qy": float, "qz": float, "qw": float,
    ///    "confidence": float }, ...] }, ...]
    TypedArray<Dictionary> get_skeleton_data();

    /// Number of joints per body in the active backend's skeleton model.
    int get_joint_count() const;

    // ── Point Cloud ──────────────────────────────────────────────────

    /// Point positions as PackedFloat32Array: [x0, y0, z0, x1, y1, z1, ...]
    PackedFloat32Array get_point_cloud_positions();

    /// Point colors as PackedByteArray RGBA8 (one per point, same count as positions/3).
    PackedByteArray get_point_cloud_colors();

    /// Point count in the last captured frame.
    int get_point_count() const;

    // ── Floor Plane ──────────────────────────────────────────────────

    /// Floor plane as Dictionary: { "nx": float, "ny": float, "nz": float, "d": float }
    /// Returns empty Dictionary if not detected or not supported.
    Dictionary get_floor_plane();

    // ── Hand Tracking ────────────────────────────────────────────────

    /// Returns hand data as Array of hand Dictionaries:
    /// [{ "hand_id": int, "is_left": bool, "confidence": float,
    ///    "grab_strength": float, "pinch_strength": float,
    ///    "palm": { "x","y","z","qx","qy","qz","qw" },
    ///    "wrist": { ... },
    ///    "fingers": [{ "name": "thumb", "bones": [{ "name": "thumb_metacarpal",
    ///       "x","y","z","qx","qy","qz","qw","confidence" }, ...] }, ...]
    /// }, ...]
    TypedArray<Dictionary> get_hand_data();

    /// Number of currently tracked hands.
    int get_hand_count() const;

private:
    std::unique_ptr<DepthSensorBackend> m_backend;
    std::string m_active_backend_name;

    // Cached frame data (filled by capture())
    std::vector<uint8_t> m_depth_buf;
    std::vector<uint8_t> m_color_buf;
    std::vector<uint8_t> m_ir_buf;
    std::vector<uint8_t> m_player_idx_buf;
    std::vector<DepthSensorBody> m_bodies;
    std::vector<float> m_pc_positions;
    std::vector<uint8_t> m_pc_colors;

    int m_depth_w = 0, m_depth_h = 0;
    int m_color_w = 0, m_color_h = 0;
    int m_ir_w = 0, m_ir_h = 0;
    int m_player_w = 0, m_player_h = 0;
    int m_point_count = 0;

    float m_floor_nx = 0, m_floor_ny = 1, m_floor_nz = 0, m_floor_d = 0;
    bool m_floor_valid = false;

    // Hand tracking cache
    std::vector<DepthSensorHand> m_hands;

    // Backend factory
    static std::unique_ptr<DepthSensorBackend> _create_backend(const std::string &name);
    static std::vector<std::string> _get_compiled_backends();
};

#endif // GN_DEPTH_SENSOR_H
