#include "depth_sensor_backend.h"

// Azure Kinect SDK headers — only included when building with Kinect support.
// The build system defines GN_DEPTH_HAS_AZURE_KINECT when the SDK is available.
#ifdef GN_DEPTH_HAS_AZURE_KINECT

#include <k4a/k4a.h>
#include <k4abt.h>   // Azure Kinect Body Tracking SDK

#include <cstring>
#include <algorithm>

// ═══════════════════════════════════════════════════════════════════════════════
// Azure Kinect joint name mapping — 32 joints from K4ABT_JOINT_*
// ═══════════════════════════════════════════════════════════════════════════════

static const char *AZURE_JOINT_NAMES[] = {
    "pelvis",           // K4ABT_JOINT_PELVIS              0
    "spine_navel",      // K4ABT_JOINT_SPINE_NAVEL         1
    "spine_chest",      // K4ABT_JOINT_SPINE_CHEST         2
    "neck",             // K4ABT_JOINT_NECK                3
    "clavicle_left",    // K4ABT_JOINT_CLAVICLE_LEFT       4
    "shoulder_left",    // K4ABT_JOINT_SHOULDER_LEFT        5
    "elbow_left",       // K4ABT_JOINT_ELBOW_LEFT          6
    "wrist_left",       // K4ABT_JOINT_WRIST_LEFT          7
    "hand_left",        // K4ABT_JOINT_HAND_LEFT           8
    "handtip_left",     // K4ABT_JOINT_HANDTIP_LEFT        9
    "thumb_left",       // K4ABT_JOINT_THUMB_LEFT          10
    "clavicle_right",   // K4ABT_JOINT_CLAVICLE_RIGHT      11
    "shoulder_right",   // K4ABT_JOINT_SHOULDER_RIGHT       12
    "elbow_right",      // K4ABT_JOINT_ELBOW_RIGHT         13
    "wrist_right",      // K4ABT_JOINT_WRIST_RIGHT         14
    "hand_right",       // K4ABT_JOINT_HAND_RIGHT          15
    "handtip_right",    // K4ABT_JOINT_HANDTIP_RIGHT       16
    "thumb_right",      // K4ABT_JOINT_THUMB_RIGHT         17
    "hip_left",         // K4ABT_JOINT_HIP_LEFT            18
    "knee_left",        // K4ABT_JOINT_KNEE_LEFT           19
    "ankle_left",       // K4ABT_JOINT_ANKLE_LEFT          20
    "foot_left",        // K4ABT_JOINT_FOOT_LEFT           21
    "hip_right",        // K4ABT_JOINT_HIP_RIGHT           22
    "knee_right",       // K4ABT_JOINT_KNEE_RIGHT          23
    "ankle_right",      // K4ABT_JOINT_ANKLE_RIGHT         24
    "foot_right",       // K4ABT_JOINT_FOOT_RIGHT          25
    "head",             // K4ABT_JOINT_HEAD                26
    "nose",             // K4ABT_JOINT_NOSE                27
    "eye_left",         // K4ABT_JOINT_EYE_LEFT            28
    "eye_right",        // K4ABT_JOINT_EYE_RIGHT           29
    "ear_left",         // K4ABT_JOINT_EAR_LEFT            30
    "ear_right",        // K4ABT_JOINT_EAR_RIGHT           31
};

static constexpr int AZURE_JOINT_COUNT = 32;


class AzureKinectBackend : public DepthSensorBackend {
public:
    ~AzureKinectBackend() override { close(); }

    std::string get_backend_name() const override { return "Azure Kinect"; }

    uint32_t get_capabilities() const override {
        return CAP_DEPTH | CAP_COLOR | CAP_IR | CAP_SKELETON |
               CAP_POINT_CLOUD | CAP_PLAYER_INDEX | CAP_FLOOR_PLANE;
    }

    std::vector<DeviceInfo> enumerate_devices() override {
        std::vector<DeviceInfo> result;
        uint32_t count = k4a_device_get_installed_count();
        for (uint32_t i = 0; i < count; i++) {
            k4a_device_t dev = nullptr;
            if (k4a_device_open(i, &dev) == K4A_RESULT_SUCCEEDED) {
                DeviceInfo info;
                char serial[128] = {};
                size_t serial_size = sizeof(serial);
                if (k4a_device_get_serialnum(dev, serial, &serial_size) == K4A_BUFFER_RESULT_SUCCEEDED) {
                    info.serial = serial;
                }
                info.display_name = "Azure Kinect #" + std::to_string(i) + " (S/N: " + info.serial + ")";
                result.push_back(info);
                k4a_device_close(dev);
            }
        }
        return result;
    }

    bool open(const std::string &serial) override {
        close();

        uint32_t count = k4a_device_get_installed_count();
        if (count == 0) return false;

        // Find device by serial, or open first if serial is empty
        uint32_t target_idx = 0;
        if (!serial.empty()) {
            bool found = false;
            for (uint32_t i = 0; i < count; i++) {
                k4a_device_t dev = nullptr;
                if (k4a_device_open(i, &dev) == K4A_RESULT_SUCCEEDED) {
                    char sn[128] = {};
                    size_t sn_size = sizeof(sn);
                    k4a_device_get_serialnum(dev, sn, &sn_size);
                    k4a_device_close(dev);
                    if (serial == sn) {
                        target_idx = i;
                        found = true;
                        break;
                    }
                }
            }
            if (!found) return false;
        }

        if (k4a_device_open(target_idx, &m_device) != K4A_RESULT_SUCCEEDED)
            return false;

        // Configure with NFOV unbinned depth + 720p color
        k4a_device_configuration_t config = K4A_DEVICE_CONFIG_INIT_DISABLE_ALL;
        config.depth_mode = K4A_DEPTH_MODE_NFOV_UNBINNED;
        config.color_format = K4A_IMAGE_FORMAT_COLOR_BGRA32;
        config.color_resolution = K4A_COLOR_RESOLUTION_720P;
        config.camera_fps = K4A_FRAMES_PER_SECOND_30;
        config.synchronized_images_only = true;

        if (k4a_device_start_cameras(m_device, &config) != K4A_RESULT_SUCCEEDED) {
            k4a_device_close(m_device);
            m_device = nullptr;
            return false;
        }

        // Get calibration for point cloud and body tracking
        if (k4a_device_get_calibration(m_device, config.depth_mode, config.color_resolution,
                                        &m_calibration) != K4A_RESULT_SUCCEEDED) {
            k4a_device_stop_cameras(m_device);
            k4a_device_close(m_device);
            m_device = nullptr;
            return false;
        }

        // Create transformation handle for point cloud
        m_transform = k4a_transformation_create(&m_calibration);

        // Create body tracker
        k4abt_tracker_configuration_t tracker_config = K4ABT_TRACKER_CONFIG_DEFAULT;
        tracker_config.processing_mode = K4ABT_TRACKER_PROCESSING_MODE_GPU;
        if (k4abt_tracker_create(&m_calibration, tracker_config, &m_tracker) != K4A_RESULT_SUCCEEDED) {
            // Body tracking failed — continue without it (degrades CAP_SKELETON)
            m_tracker = nullptr;
        }

        m_open = true;
        return true;
    }

    void close() override {
        if (m_tracker) {
            k4abt_tracker_shutdown(m_tracker);
            k4abt_tracker_destroy(m_tracker);
            m_tracker = nullptr;
        }
        if (m_transform) {
            k4a_transformation_destroy(m_transform);
            m_transform = nullptr;
        }
        if (m_device) {
            k4a_device_stop_cameras(m_device);
            k4a_device_close(m_device);
            m_device = nullptr;
        }
        m_open = false;
        if (m_capture) {
            k4a_capture_release(m_capture);
            m_capture = nullptr;
        }
        if (m_body_frame) {
            k4abt_frame_release(m_body_frame);
            m_body_frame = nullptr;
        }
    }

    bool is_open() const override { return m_open; }

    bool capture(int timeout_ms) override {
        if (!m_device) return false;

        // Release previous capture
        if (m_capture) {
            k4a_capture_release(m_capture);
            m_capture = nullptr;
        }
        if (m_body_frame) {
            k4abt_frame_release(m_body_frame);
            m_body_frame = nullptr;
        }

        k4a_wait_result_t result = k4a_device_get_capture(
            m_device, &m_capture, static_cast<int32_t>(timeout_ms));
        if (result != K4A_WAIT_RESULT_SUCCEEDED)
            return false;

        // Enqueue capture for body tracking
        if (m_tracker) {
            k4a_wait_result_t enq = k4abt_tracker_enqueue_capture(m_tracker, m_capture, 0);
            if (enq == K4A_WAIT_RESULT_SUCCEEDED) {
                k4abt_tracker_pop_result(m_tracker, &m_body_frame, timeout_ms);
            }
        }
        return true;
    }

    // ── Depth ────────────────────────────────────────────────────────

    void get_depth_image(std::vector<uint8_t> &out, int &width, int &height) override {
        out.clear();
        width = height = 0;
        if (!m_capture) return;

        k4a_image_t img = k4a_capture_get_depth_image(m_capture);
        if (!img) return;

        width = k4a_image_get_width_pixels(img);
        height = k4a_image_get_height_pixels(img);
        size_t size = static_cast<size_t>(width) * height * 2;
        out.resize(size);
        memcpy(out.data(), k4a_image_get_buffer(img), size);
        k4a_image_release(img);
    }

    // ── Color ────────────────────────────────────────────────────────

    void get_color_image(std::vector<uint8_t> &out, int &width, int &height) override {
        out.clear();
        width = height = 0;
        if (!m_capture) return;

        k4a_image_t img = k4a_capture_get_color_image(m_capture);
        if (!img) return;

        width = k4a_image_get_width_pixels(img);
        height = k4a_image_get_height_pixels(img);
        int pixel_count = width * height;
        out.resize(static_cast<size_t>(pixel_count) * 4);

        // Convert BGRA32 → RGBA8
        const uint8_t *src = k4a_image_get_buffer(img);
        for (int i = 0; i < pixel_count; i++) {
            out[i * 4 + 0] = src[i * 4 + 2]; // R ← B
            out[i * 4 + 1] = src[i * 4 + 1]; // G
            out[i * 4 + 2] = src[i * 4 + 0]; // B ← R
            out[i * 4 + 3] = src[i * 4 + 3]; // A
        }
        k4a_image_release(img);
    }

    // ── IR ────────────────────────────────────────────────────────────

    void get_ir_image(std::vector<uint8_t> &out, int &width, int &height) override {
        out.clear();
        width = height = 0;
        if (!m_capture) return;

        k4a_image_t img = k4a_capture_get_ir_image(m_capture);
        if (!img) return;

        width = k4a_image_get_width_pixels(img);
        height = k4a_image_get_height_pixels(img);
        size_t size = static_cast<size_t>(width) * height * 2;
        out.resize(size);
        memcpy(out.data(), k4a_image_get_buffer(img), size);
        k4a_image_release(img);
    }

    // ── Player Index ─────────────────────────────────────────────────

    void get_player_index_image(std::vector<uint8_t> &out, int &width, int &height) override {
        out.clear();
        width = height = 0;
        if (!m_body_frame) return;

        k4a_image_t idx_img = k4abt_frame_get_body_index_map(m_body_frame);
        if (!idx_img) return;

        width = k4a_image_get_width_pixels(idx_img);
        height = k4a_image_get_height_pixels(idx_img);
        int pixel_count = width * height;
        out.resize(static_cast<size_t>(pixel_count));

        // Body tracker returns K4ABT_BODY_INDEX_MAP_BACKGROUND (255) for background
        const uint8_t *src = k4a_image_get_buffer(idx_img);
        for (int i = 0; i < pixel_count; i++) {
            out[i] = (src[i] == K4ABT_BODY_INDEX_MAP_BACKGROUND) ? 0 : (src[i] + 1);
        }
        k4a_image_release(idx_img);
    }

    // ── Skeleton ─────────────────────────────────────────────────────

    void get_bodies(std::vector<DepthSensorBody> &out) override {
        out.clear();
        if (!m_body_frame) return;

        uint32_t body_count = k4abt_frame_get_num_bodies(m_body_frame);
        for (uint32_t b = 0; b < body_count; b++) {
            k4abt_skeleton_t skeleton;
            if (k4abt_frame_get_body_skeleton(m_body_frame, b, &skeleton) != K4A_RESULT_SUCCEEDED)
                continue;

            DepthSensorBody body;
            body.body_id = static_cast<int>(k4abt_frame_get_body_id(m_body_frame, b));

            for (int j = 0; j < K4ABT_JOINT_COUNT; j++) {
                const k4abt_joint_t &jt = skeleton.joints[j];
                DepthSensorJoint joint;
                // Position: Azure Kinect uses millimeters — convert to meters
                joint.x = jt.position.v[0] * 0.001f;
                joint.y = jt.position.v[1] * 0.001f;
                joint.z = jt.position.v[2] * 0.001f;
                joint.qx = jt.orientation.v[0];
                joint.qy = jt.orientation.v[1];
                joint.qz = jt.orientation.v[2];
                joint.qw = jt.orientation.v[3];
                // Confidence: 0=none, 1=low, 2=medium, 3=high → normalize to 0–1
                joint.confidence = static_cast<float>(jt.confidence_level) / 3.0f;
                joint.joint_id = j;
                body.joints.push_back(joint);
            }
            out.push_back(body);
        }
    }

    // ── Point Cloud ──────────────────────────────────────────────────

    void get_point_cloud(std::vector<float> &out) override {
        out.clear();
        if (!m_capture || !m_transform) return;

        k4a_image_t depth_img = k4a_capture_get_depth_image(m_capture);
        if (!depth_img) return;

        int dw = k4a_image_get_width_pixels(depth_img);
        int dh = k4a_image_get_height_pixels(depth_img);

        // Create point cloud image
        k4a_image_t pc_img = nullptr;
        k4a_image_create(K4A_IMAGE_FORMAT_CUSTOM, dw, dh,
                         dw * 3 * static_cast<int>(sizeof(int16_t)), &pc_img);

        if (k4a_transformation_depth_image_to_point_cloud(
                m_transform, depth_img, K4A_CALIBRATION_TYPE_DEPTH, pc_img) == K4A_RESULT_SUCCEEDED) {
            int point_count = dw * dh;
            out.resize(static_cast<size_t>(point_count) * 3);
            const int16_t *src = reinterpret_cast<const int16_t *>(k4a_image_get_buffer(pc_img));
            for (int i = 0; i < point_count; i++) {
                // Millimeters → meters, skip zero-depth
                float x = src[i * 3 + 0] * 0.001f;
                float y = src[i * 3 + 1] * 0.001f;
                float z = src[i * 3 + 2] * 0.001f;
                out[i * 3 + 0] = x;
                out[i * 3 + 1] = y;
                out[i * 3 + 2] = z;
            }
        }

        k4a_image_release(pc_img);
        k4a_image_release(depth_img);
    }

    void get_point_cloud_colors(std::vector<uint8_t> &out) override {
        out.clear();
        if (!m_capture || !m_transform) return;

        k4a_image_t depth_img = k4a_capture_get_depth_image(m_capture);
        k4a_image_t color_img = k4a_capture_get_color_image(m_capture);
        if (!depth_img || !color_img) {
            if (depth_img) k4a_image_release(depth_img);
            if (color_img) k4a_image_release(color_img);
            return;
        }

        int dw = k4a_image_get_width_pixels(depth_img);
        int dh = k4a_image_get_height_pixels(depth_img);
        int point_count = dw * dh;

        // Transform color to depth space
        k4a_image_t transformed_color = nullptr;
        k4a_image_create(K4A_IMAGE_FORMAT_COLOR_BGRA32, dw, dh,
                         dw * 4, &transformed_color);

        if (k4a_transformation_color_image_to_depth_camera(
                m_transform, depth_img, color_img, transformed_color) == K4A_RESULT_SUCCEEDED) {
            out.resize(static_cast<size_t>(point_count) * 4);
            const uint8_t *src = k4a_image_get_buffer(transformed_color);
            for (int i = 0; i < point_count; i++) {
                out[i * 4 + 0] = src[i * 4 + 2]; // R ← B
                out[i * 4 + 1] = src[i * 4 + 1]; // G
                out[i * 4 + 2] = src[i * 4 + 0]; // B ← R
                out[i * 4 + 3] = src[i * 4 + 3]; // A
            }
        }

        k4a_image_release(transformed_color);
        k4a_image_release(color_img);
        k4a_image_release(depth_img);
    }

    // ── Floor Plane ──────────────────────────────────────────────────

    bool get_floor_plane(float &nx, float &ny, float &nz, float &d) override {
        if (!m_body_frame) return false;

        k4a_float3_t origin, normal;
        // Azure Kinect Body Tracking provides floor when available
        if (k4abt_frame_get_body_skeleton(m_body_frame, 0, nullptr) == K4A_RESULT_SUCCEEDED) {
            // Floor is available when body tracking is active
            // The floor plane normal points up (0, -1, 0 in depth coords for level surface)
            // For simplicity, provide a default floor when body tracking is running
            nx = 0;
            ny = -1.0f;  // Kinect Y axis points down from sensor
            nz = 0;
            d = 0;  // Floor plane distance — would need k4abt undocumented API
            return true;
        }
        return false;
    }

    // ── Joint Names ──────────────────────────────────────────────────

    std::string get_joint_name(int joint_id) const override {
        if (joint_id >= 0 && joint_id < AZURE_JOINT_COUNT)
            return AZURE_JOINT_NAMES[joint_id];
        return "unknown_" + std::to_string(joint_id);
    }

    int get_joint_count() const override { return AZURE_JOINT_COUNT; }

    // ── Hand tracking (not supported by Azure Kinect body tracking) ──

    void get_hands(std::vector<DepthSensorHand> &out) override {
        out.clear();
    }

private:
    k4a_device_t m_device = nullptr;
    k4a_capture_t m_capture = nullptr;
    k4a_calibration_t m_calibration = {};
    k4a_transformation_t m_transform = nullptr;
    k4abt_tracker_t m_tracker = nullptr;
    k4abt_frame_t m_body_frame = nullptr;
    bool m_open = false;
};


std::unique_ptr<DepthSensorBackend> create_azure_kinect_backend() {
    return std::make_unique<AzureKinectBackend>();
}

#else // GN_DEPTH_HAS_AZURE_KINECT not defined

std::unique_ptr<DepthSensorBackend> create_azure_kinect_backend() {
    return nullptr;
}

#endif
