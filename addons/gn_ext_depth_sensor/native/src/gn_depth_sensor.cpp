#include "gn_depth_sensor.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <algorithm>
#include <cstring>

using namespace godot;

// Forward-declare backend factories (defined in their own .cpp files).
// Each returns nullptr if the SDK is not compiled in.
extern std::unique_ptr<DepthSensorBackend> create_azure_kinect_backend();
extern std::unique_ptr<DepthSensorBackend> create_realsense_backend();
extern std::unique_ptr<DepthSensorBackend> create_ultraleap_backend();


// ═══════════════════════════════════════════════════════════════════════════════
// Static helpers
// ═══════════════════════════════════════════════════════════════════════════════

std::vector<std::string> GNDepthSensor::_get_compiled_backends() {
    std::vector<std::string> backends;
#ifdef GN_DEPTH_HAS_AZURE_KINECT
    backends.push_back("azure_kinect");
#endif
#ifdef GN_DEPTH_HAS_REALSENSE
    backends.push_back("realsense");
#endif
#ifdef GN_DEPTH_HAS_ULTRALEAP
    backends.push_back("ultraleap");
#endif
    return backends;
}

std::unique_ptr<DepthSensorBackend> GNDepthSensor::_create_backend(const std::string &name) {
#ifdef GN_DEPTH_HAS_AZURE_KINECT
    if (name == "azure_kinect") return create_azure_kinect_backend();
#endif
#ifdef GN_DEPTH_HAS_REALSENSE
    if (name == "realsense") return create_realsense_backend();
#endif
#ifdef GN_DEPTH_HAS_ULTRALEAP
    if (name == "ultraleap") return create_ultraleap_backend();
#endif
    return nullptr;
}


// ═══════════════════════════════════════════════════════════════════════════════
// Construction / Destruction
// ═══════════════════════════════════════════════════════════════════════════════

GNDepthSensor::GNDepthSensor() {}

GNDepthSensor::~GNDepthSensor() {
    close_device();
}


// ═══════════════════════════════════════════════════════════════════════════════
// Godot binding
// ═══════════════════════════════════════════════════════════════════════════════

void GNDepthSensor::_bind_methods() {
    // Backend / Device
    ClassDB::bind_method(D_METHOD("get_available_backends"), &GNDepthSensor::get_available_backends);
    ClassDB::bind_method(D_METHOD("enumerate_devices"), &GNDepthSensor::enumerate_devices);
    ClassDB::bind_method(D_METHOD("open_device", "serial", "backend_name"), &GNDepthSensor::open_device);
    ClassDB::bind_method(D_METHOD("close_device"), &GNDepthSensor::close_device);
    ClassDB::bind_method(D_METHOD("is_device_open"), &GNDepthSensor::is_device_open);
    ClassDB::bind_method(D_METHOD("get_capabilities"), &GNDepthSensor::get_capabilities);
    ClassDB::bind_method(D_METHOD("has_capability", "cap"), &GNDepthSensor::has_capability);
    ClassDB::bind_method(D_METHOD("get_active_backend"), &GNDepthSensor::get_active_backend);

    // Capture
    ClassDB::bind_method(D_METHOD("capture", "timeout_ms"), &GNDepthSensor::capture, DEFVAL(33));

    // Image streams
    ClassDB::bind_method(D_METHOD("get_depth_rgba", "max_mm"), &GNDepthSensor::get_depth_rgba, DEFVAL(5000));
    ClassDB::bind_method(D_METHOD("get_depth_width"), &GNDepthSensor::get_depth_width);
    ClassDB::bind_method(D_METHOD("get_depth_height"), &GNDepthSensor::get_depth_height);
    ClassDB::bind_method(D_METHOD("get_depth_raw"), &GNDepthSensor::get_depth_raw);
    ClassDB::bind_method(D_METHOD("get_color_rgba"), &GNDepthSensor::get_color_rgba);
    ClassDB::bind_method(D_METHOD("get_color_width"), &GNDepthSensor::get_color_width);
    ClassDB::bind_method(D_METHOD("get_color_height"), &GNDepthSensor::get_color_height);
    ClassDB::bind_method(D_METHOD("get_ir_rgba"), &GNDepthSensor::get_ir_rgba);
    ClassDB::bind_method(D_METHOD("get_ir_width"), &GNDepthSensor::get_ir_width);
    ClassDB::bind_method(D_METHOD("get_ir_height"), &GNDepthSensor::get_ir_height);
    ClassDB::bind_method(D_METHOD("get_player_index_rgba"), &GNDepthSensor::get_player_index_rgba);

    // Skeleton
    ClassDB::bind_method(D_METHOD("get_skeleton_data"), &GNDepthSensor::get_skeleton_data);
    ClassDB::bind_method(D_METHOD("get_joint_count"), &GNDepthSensor::get_joint_count);

    // Point cloud
    ClassDB::bind_method(D_METHOD("get_point_cloud_positions"), &GNDepthSensor::get_point_cloud_positions);
    ClassDB::bind_method(D_METHOD("get_point_cloud_colors"), &GNDepthSensor::get_point_cloud_colors);
    ClassDB::bind_method(D_METHOD("get_point_count"), &GNDepthSensor::get_point_count);

    // Floor plane
    ClassDB::bind_method(D_METHOD("get_floor_plane"), &GNDepthSensor::get_floor_plane);

    // Hands
    ClassDB::bind_method(D_METHOD("get_hand_data"), &GNDepthSensor::get_hand_data);
    ClassDB::bind_method(D_METHOD("get_hand_count"), &GNDepthSensor::get_hand_count);

    // Capability flag constants
    BIND_CONSTANT(CAP_NONE);
    BIND_CONSTANT(CAP_DEPTH);
    BIND_CONSTANT(CAP_COLOR);
    BIND_CONSTANT(CAP_IR);
    BIND_CONSTANT(CAP_SKELETON);
    BIND_CONSTANT(CAP_POINT_CLOUD);
    BIND_CONSTANT(CAP_PLAYER_INDEX);
    BIND_CONSTANT(CAP_FLOOR_PLANE);
    BIND_CONSTANT(CAP_HAND_TRACK);
}


// ═══════════════════════════════════════════════════════════════════════════════
// Backend / Device Management
// ═══════════════════════════════════════════════════════════════════════════════

PackedStringArray GNDepthSensor::get_available_backends() {
    PackedStringArray result;
    for (const auto &b : _get_compiled_backends()) {
        result.push_back(String(b.c_str()));
    }
    return result;
}

TypedArray<Dictionary> GNDepthSensor::enumerate_devices() {
    TypedArray<Dictionary> result;
    for (const auto &backend_name : _get_compiled_backends()) {
        auto backend = _create_backend(backend_name);
        if (!backend) continue;
        auto devices = backend->enumerate_devices();
        for (const auto &dev : devices) {
            Dictionary d;
            d["serial"] = String(dev.serial.c_str());
            d["name"] = String(dev.display_name.c_str());
            d["backend"] = String(backend_name.c_str());
            result.push_back(d);
        }
    }
    return result;
}

bool GNDepthSensor::open_device(const String &serial, const String &backend_name) {
    close_device();

    std::string bn = backend_name.utf8().get_data();
    m_backend = _create_backend(bn);
    if (!m_backend) {
        UtilityFunctions::printerr("[GNDepthSensor] Unknown backend: ", backend_name);
        return false;
    }

    std::string serial_str = serial.utf8().get_data();
    if (!m_backend->open(serial_str)) {
        UtilityFunctions::printerr("[GNDepthSensor] Failed to open device: ", serial);
        m_backend.reset();
        return false;
    }

    m_active_backend_name = bn;
    return true;
}

void GNDepthSensor::close_device() {
    if (m_backend) {
        m_backend->close();
        m_backend.reset();
    }
    m_active_backend_name.clear();
    m_depth_w = m_depth_h = 0;
    m_color_w = m_color_h = 0;
    m_ir_w = m_ir_h = 0;
    m_point_count = 0;
    m_floor_valid = false;
    m_hands.clear();
}

bool GNDepthSensor::is_device_open() const {
    return m_backend && m_backend->is_open();
}

int GNDepthSensor::get_capabilities() const {
    return m_backend ? static_cast<int>(m_backend->get_capabilities()) : 0;
}

bool GNDepthSensor::has_capability(int cap) const {
    return m_backend && (m_backend->get_capabilities() & static_cast<uint32_t>(cap)) != 0;
}

String GNDepthSensor::get_active_backend() const {
    return String(m_active_backend_name.c_str());
}


// ═══════════════════════════════════════════════════════════════════════════════
// Frame Capture
// ═══════════════════════════════════════════════════════════════════════════════

bool GNDepthSensor::capture(int timeout_ms) {
    if (!m_backend || !m_backend->is_open()) return false;

    bool ok = m_backend->capture(timeout_ms);
    if (!ok) return false;

    uint32_t caps = m_backend->get_capabilities();

    // Pull all supported streams into cached buffers
    if (caps & CAP_DEPTH)
        m_backend->get_depth_image(m_depth_buf, m_depth_w, m_depth_h);

    if (caps & CAP_COLOR)
        m_backend->get_color_image(m_color_buf, m_color_w, m_color_h);

    if (caps & CAP_IR)
        m_backend->get_ir_image(m_ir_buf, m_ir_w, m_ir_h);

    if (caps & CAP_PLAYER_INDEX)
        m_backend->get_player_index_image(m_player_idx_buf, m_player_w, m_player_h);

    if (caps & CAP_SKELETON)
        m_backend->get_bodies(m_bodies);

    if (caps & CAP_POINT_CLOUD) {
        m_backend->get_point_cloud(m_pc_positions);
        m_backend->get_point_cloud_colors(m_pc_colors);
        m_point_count = static_cast<int>(m_pc_positions.size() / 3);
    }

    if (caps & CAP_FLOOR_PLANE)
        m_floor_valid = m_backend->get_floor_plane(m_floor_nx, m_floor_ny, m_floor_nz, m_floor_d);

    if (caps & CAP_HAND_TRACK)
        m_backend->get_hands(m_hands);

    return true;
}


// ═══════════════════════════════════════════════════════════════════════════════
// Image Streams
// ═══════════════════════════════════════════════════════════════════════════════

PackedByteArray GNDepthSensor::get_depth_rgba(int max_mm) {
    if (m_depth_buf.empty() || m_depth_w <= 0 || m_depth_h <= 0)
        return PackedByteArray();

    int pixel_count = m_depth_w * m_depth_h;
    PackedByteArray out;
    out.resize(pixel_count * 4);
    uint8_t *dst = out.ptrw();
    const uint8_t *src = m_depth_buf.data();
    float inv_max = (max_mm > 0) ? (255.0f / static_cast<float>(max_mm)) : 0.0f;

    for (int i = 0; i < pixel_count; i++) {
        // 16-bit LE depth in millimeters
        uint16_t depth_mm = static_cast<uint16_t>(src[i * 2]) |
                            (static_cast<uint16_t>(src[i * 2 + 1]) << 8);
        uint8_t val = 0;
        if (depth_mm > 0 && depth_mm < static_cast<uint16_t>(max_mm)) {
            val = static_cast<uint8_t>(255 - std::min(255.0f, static_cast<float>(depth_mm) * inv_max));
        }
        dst[i * 4 + 0] = val;
        dst[i * 4 + 1] = val;
        dst[i * 4 + 2] = val;
        dst[i * 4 + 3] = (depth_mm > 0) ? 255 : 0;
    }
    return out;
}

int GNDepthSensor::get_depth_width() const { return m_depth_w; }
int GNDepthSensor::get_depth_height() const { return m_depth_h; }

PackedByteArray GNDepthSensor::get_depth_raw() {
    if (m_depth_buf.empty()) return PackedByteArray();
    PackedByteArray out;
    out.resize(static_cast<int>(m_depth_buf.size()));
    memcpy(out.ptrw(), m_depth_buf.data(), m_depth_buf.size());
    return out;
}

PackedByteArray GNDepthSensor::get_color_rgba() {
    if (m_color_buf.empty()) return PackedByteArray();
    PackedByteArray out;
    out.resize(static_cast<int>(m_color_buf.size()));
    memcpy(out.ptrw(), m_color_buf.data(), m_color_buf.size());
    return out;
}

int GNDepthSensor::get_color_width() const { return m_color_w; }
int GNDepthSensor::get_color_height() const { return m_color_h; }

PackedByteArray GNDepthSensor::get_ir_rgba() {
    if (m_ir_buf.empty() || m_ir_w <= 0 || m_ir_h <= 0)
        return PackedByteArray();

    int pixel_count = m_ir_w * m_ir_h;
    PackedByteArray out;
    out.resize(pixel_count * 4);
    uint8_t *dst = out.ptrw();
    const uint8_t *src = m_ir_buf.data();

    for (int i = 0; i < pixel_count; i++) {
        uint16_t ir_val = static_cast<uint16_t>(src[i * 2]) |
                          (static_cast<uint16_t>(src[i * 2 + 1]) << 8);
        // Normalize 16-bit IR to 8-bit (typically 0–1000 range)
        uint8_t val = static_cast<uint8_t>(std::min(255, static_cast<int>(ir_val >> 2)));
        dst[i * 4 + 0] = val;
        dst[i * 4 + 1] = val;
        dst[i * 4 + 2] = val;
        dst[i * 4 + 3] = 255;
    }
    return out;
}

int GNDepthSensor::get_ir_width() const { return m_ir_w; }
int GNDepthSensor::get_ir_height() const { return m_ir_h; }

PackedByteArray GNDepthSensor::get_player_index_rgba() {
    if (m_player_idx_buf.empty() || m_player_w <= 0 || m_player_h <= 0)
        return PackedByteArray();

    // Distinct colors for up to 8 body IDs
    static const uint8_t BODY_COLORS[][3] = {
        {  0,   0,   0}, // 0 = background
        {255,  64,  64}, // body 1 — red
        { 64, 255,  64}, // body 2 — green
        { 64,  64, 255}, // body 3 — blue
        {255, 255,  64}, // body 4 — yellow
        {255,  64, 255}, // body 5 — magenta
        { 64, 255, 255}, // body 6 — cyan
        {255, 160,  64}, // body 7 — orange
    };

    int pixel_count = m_player_w * m_player_h;
    PackedByteArray out;
    out.resize(pixel_count * 4);
    uint8_t *dst = out.ptrw();

    for (int i = 0; i < pixel_count; i++) {
        int idx = std::min(static_cast<int>(m_player_idx_buf[i]), 7);
        dst[i * 4 + 0] = BODY_COLORS[idx][0];
        dst[i * 4 + 1] = BODY_COLORS[idx][1];
        dst[i * 4 + 2] = BODY_COLORS[idx][2];
        dst[i * 4 + 3] = (idx > 0) ? 255 : 0;
    }
    return out;
}


// ═══════════════════════════════════════════════════════════════════════════════
// Skeleton
// ═══════════════════════════════════════════════════════════════════════════════

TypedArray<Dictionary> GNDepthSensor::get_skeleton_data() {
    TypedArray<Dictionary> result;
    if (!m_backend) return result;

    for (const auto &body : m_bodies) {
        Dictionary body_dict;
        body_dict["body_id"] = body.body_id;

        TypedArray<Dictionary> joints;
        for (const auto &j : body.joints) {
            Dictionary jd;
            jd["name"] = String(m_backend->get_joint_name(j.joint_id).c_str());
            jd["x"] = j.x;
            jd["y"] = j.y;
            jd["z"] = j.z;
            jd["qx"] = j.qx;
            jd["qy"] = j.qy;
            jd["qz"] = j.qz;
            jd["qw"] = j.qw;
            jd["confidence"] = j.confidence;
            joints.push_back(jd);
        }
        body_dict["joints"] = joints;
        result.push_back(body_dict);
    }
    return result;
}

int GNDepthSensor::get_joint_count() const {
    return m_backend ? m_backend->get_joint_count() : 0;
}


// ═══════════════════════════════════════════════════════════════════════════════
// Point Cloud
// ═══════════════════════════════════════════════════════════════════════════════

PackedFloat32Array GNDepthSensor::get_point_cloud_positions() {
    if (m_pc_positions.empty()) return PackedFloat32Array();
    PackedFloat32Array out;
    out.resize(static_cast<int>(m_pc_positions.size()));
    memcpy(out.ptrw(), m_pc_positions.data(), m_pc_positions.size() * sizeof(float));
    return out;
}

PackedByteArray GNDepthSensor::get_point_cloud_colors() {
    if (m_pc_colors.empty()) return PackedByteArray();
    PackedByteArray out;
    out.resize(static_cast<int>(m_pc_colors.size()));
    memcpy(out.ptrw(), m_pc_colors.data(), m_pc_colors.size());
    return out;
}

int GNDepthSensor::get_point_count() const {
    return m_point_count;
}


// ═══════════════════════════════════════════════════════════════════════════════
// Floor Plane
// ═══════════════════════════════════════════════════════════════════════════════

Dictionary GNDepthSensor::get_floor_plane() {
    Dictionary result;
    if (!m_floor_valid) return result;
    result["nx"] = m_floor_nx;
    result["ny"] = m_floor_ny;
    result["nz"] = m_floor_nz;
    result["d"] = m_floor_d;
    return result;
}


// ═══════════════════════════════════════════════════════════════════════════════
// Hand Tracking
// ═══════════════════════════════════════════════════════════════════════════════

static Dictionary _joint_to_dict(const DepthSensorJoint &j, const String &name) {
    Dictionary d;
    d["name"] = name;
    d["x"] = j.x;
    d["y"] = j.y;
    d["z"] = j.z;
    d["qx"] = j.qx;
    d["qy"] = j.qy;
    d["qz"] = j.qz;
    d["qw"] = j.qw;
    d["confidence"] = j.confidence;
    return d;
}

TypedArray<Dictionary> GNDepthSensor::get_hand_data() {
    TypedArray<Dictionary> result;
    if (!m_backend) return result;

    static const char *FINGER_NAMES[] = {"thumb", "index", "middle", "ring", "pinky"};

    for (const auto &hand : m_hands) {
        Dictionary hd;
        hd["hand_id"] = hand.hand_id;
        hd["is_left"] = hand.is_left;
        hd["confidence"] = hand.confidence;
        hd["grab_strength"] = hand.grab_strength;
        hd["pinch_strength"] = hand.pinch_strength;
        hd["palm"] = _joint_to_dict(hand.palm, "palm");
        hd["wrist"] = _joint_to_dict(hand.wrist, "wrist");

        TypedArray<Dictionary> fingers;
        for (int f = 0; f < 5; f++) {
            Dictionary fd;
            fd["name"] = String(FINGER_NAMES[f]);

            TypedArray<Dictionary> bones;
            for (int b = 0; b < 5; b++) {
                String bone_name = String(DepthSensorBackend::get_finger_bone_name(f, b).c_str());
                bones.push_back(_joint_to_dict(hand.fingers[f].bones[b], bone_name));
            }
            fd["bones"] = bones;
            fingers.push_back(fd);
        }
        hd["fingers"] = fingers;
        result.push_back(hd);
    }
    return result;
}

int GNDepthSensor::get_hand_count() const {
    return static_cast<int>(m_hands.size());
}
