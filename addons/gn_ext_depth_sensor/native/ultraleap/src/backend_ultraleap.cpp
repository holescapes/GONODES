#include "depth_sensor_backend.h"

// Ultraleap (Leap Motion) SDK — only compiled with Ultraleap support.
#ifdef GN_DEPTH_HAS_ULTRALEAP

#include <LeapC.h>

#include <cstring>
#include <algorithm>

class UltraleapBackend : public DepthSensorBackend {
public:
    ~UltraleapBackend() override { close(); }

    std::string get_backend_name() const override { return "Ultraleap"; }

    uint32_t get_capabilities() const override {
        // Ultraleap: hand tracking only (no depth image, no color, no body skeleton)
        return CAP_HAND_TRACK;
    }

    std::vector<DeviceInfo> enumerate_devices() override {
        std::vector<DeviceInfo> result;

        LEAP_CONNECTION tmp_conn = nullptr;
        LEAP_CONNECTION_CONFIG cfg = {};
        cfg.size = sizeof(cfg);
        if (LeapCreateConnection(&cfg, &tmp_conn) != eLeapRS_Success) return result;
        if (LeapOpenConnection(tmp_conn) != eLeapRS_Success) {
            LeapDestroyConnection(tmp_conn);
            return result;
        }

        // Poll for a device event (100ms timeout)
        LEAP_CONNECTION_MESSAGE msg;
        for (int attempts = 0; attempts < 10; attempts++) {
            eLeapRS rs = LeapPollConnection(tmp_conn, 100, &msg);
            if (rs == eLeapRS_Success && msg.type == eLeapEventType_Device) {
                break;
            }
        }

        // Enumerate connected devices
        uint32_t count = 0;
        LeapGetDeviceList(tmp_conn, nullptr, &count);
        if (count > 0) {
            std::vector<LEAP_DEVICE_REF> refs(count);
            LeapGetDeviceList(tmp_conn, refs.data(), &count);

            for (uint32_t i = 0; i < count; i++) {
                LEAP_DEVICE dev;
                if (LeapOpenDevice(refs[i], &dev) == eLeapRS_Success) {
                    LEAP_DEVICE_INFO info = {};
                    info.size = sizeof(info);
                    info.serial_length = 256;
                    char serial_buf[256] = {};
                    info.serial = serial_buf;

                    if (LeapGetDeviceInfo(dev, &info) == eLeapRS_Success) {
                        DeviceInfo di;
                        di.serial = serial_buf;
                        di.display_name = "Ultraleap (" + di.serial + ")";
                        result.push_back(di);
                    }
                    LeapCloseDevice(dev);
                }
            }
        }

        LeapCloseConnection(tmp_conn);
        LeapDestroyConnection(tmp_conn);
        return result;
    }

    bool open(const std::string &serial) override {
        close();

        LEAP_CONNECTION_CONFIG cfg = {};
        cfg.size = sizeof(cfg);
        if (LeapCreateConnection(&cfg, &m_connection) != eLeapRS_Success) return false;
        if (LeapOpenConnection(m_connection) != eLeapRS_Success) {
            LeapDestroyConnection(m_connection);
            m_connection = nullptr;
            return false;
        }

        // Wait for connection to establish
        LEAP_CONNECTION_MESSAGE msg;
        for (int attempts = 0; attempts < 50; attempts++) {
            eLeapRS rs = LeapPollConnection(m_connection, 100, &msg);
            if (rs == eLeapRS_Success && msg.type == eLeapEventType_Tracking) {
                break;
            }
        }

        m_serial = serial;
        m_open = true;
        return true;
    }

    void close() override {
        if (m_connection) {
            LeapCloseConnection(m_connection);
            LeapDestroyConnection(m_connection);
            m_connection = nullptr;
        }
        m_open = false;
    }

    bool is_open() const override { return m_open && m_connection != nullptr; }

    bool capture(int timeout_ms) override {
        if (!m_connection) return false;

        LEAP_CONNECTION_MESSAGE msg;
        eLeapRS rs = LeapPollConnection(m_connection, static_cast<uint32_t>(timeout_ms), &msg);
        if (rs != eLeapRS_Success) return false;

        // Process tracking events; skip non-tracking messages
        if (msg.type == eLeapEventType_Tracking) {
            m_last_frame = msg.tracking_event;
            m_has_frame = true;
            return true;
        }

        // Non-tracking event received — still valid but no new hand data
        return m_has_frame;
    }

    // ── Image streams (not supported) ────────────────────────────────

    void get_depth_image(std::vector<uint8_t> &out, int &w, int &h) override {
        out.clear(); w = 0; h = 0;
    }

    void get_color_image(std::vector<uint8_t> &out, int &w, int &h) override {
        out.clear(); w = 0; h = 0;
    }

    void get_ir_image(std::vector<uint8_t> &out, int &w, int &h) override {
        out.clear(); w = 0; h = 0;
    }

    void get_player_index_image(std::vector<uint8_t> &buf, int &w, int &h) override {
        buf.clear(); w = 0; h = 0;
    }

    // ── Body tracking (not supported) ────────────────────────────────

    void get_bodies(std::vector<DepthSensorBody> &out) override {
        out.clear();
    }

    std::string get_joint_name(int joint_id) const override {
        return "unsupported";
    }

    int get_joint_count() const override { return 0; }

    // ── Point cloud (not supported) ──────────────────────────────────

    void get_point_cloud(std::vector<float> &out) override { out.clear(); }

    void get_point_cloud_colors(std::vector<uint8_t> &out) override { out.clear(); }

    // ── Floor plane (not supported) ──────────────────────────────────

    bool get_floor_plane(float &nx, float &ny, float &nz, float &d) override {
        return false;
    }

    // ── Hand tracking (core capability) ──────────────────────────────

    void get_hands(std::vector<DepthSensorHand> &out) override {
        out.clear();
        if (!m_has_frame || !m_last_frame) return;

        const LEAP_TRACKING_EVENT *frame = m_last_frame;

        for (uint32_t h = 0; h < frame->nHands; h++) {
            const LEAP_HAND &lh = frame->pHands[h];

            DepthSensorHand hand;
            hand.hand_id = (lh.type == eLeapHandType_Left) ? 0 : 1;
            hand.is_left = (lh.type == eLeapHandType_Left);
            hand.confidence = lh.confidence;
            hand.grab_strength = lh.grab_strength;
            hand.pinch_strength = lh.pinch_strength;

            // Palm — convert mm to meters
            hand.palm.joint_id = -1;
            hand.palm.x = lh.palm.position.x * 0.001f;
            hand.palm.y = lh.palm.position.y * 0.001f;
            hand.palm.z = lh.palm.position.z * 0.001f;
            hand.palm.qx = lh.palm.orientation.x;
            hand.palm.qy = lh.palm.orientation.y;
            hand.palm.qz = lh.palm.orientation.z;
            hand.palm.qw = lh.palm.orientation.w;
            hand.palm.confidence = lh.confidence;

            // Wrist
            hand.wrist.joint_id = -2;
            hand.wrist.x = lh.arm.next_joint.x * 0.001f;
            hand.wrist.y = lh.arm.next_joint.y * 0.001f;
            hand.wrist.z = lh.arm.next_joint.z * 0.001f;
            hand.wrist.qx = lh.arm.rotation.x;
            hand.wrist.qy = lh.arm.rotation.y;
            hand.wrist.qz = lh.arm.rotation.z;
            hand.wrist.qw = lh.arm.rotation.w;
            hand.wrist.confidence = lh.confidence;

            // 5 fingers: thumb, index, middle, ring, pinky
            const LEAP_DIGIT *digits[] = {
                &lh.thumb, &lh.index, &lh.middle, &lh.ring, &lh.pinky
            };

            for (int f = 0; f < 5; f++) {
                const LEAP_DIGIT &digit = *digits[f];
                // 4 bones in LEAP_DIGIT: metacarpal, proximal, intermediate, distal
                const LEAP_BONE *bones[] = {
                    &digit.metacarpal, &digit.proximal,
                    &digit.intermediate, &digit.distal
                };

                for (int b = 0; b < 4; b++) {
                    const LEAP_BONE &bone = *bones[b];
                    DepthSensorJoint &j = hand.fingers[f].bones[b];
                    j.joint_id = f * 5 + b;
                    // Use prev_joint as bone start position
                    j.x = bone.prev_joint.x * 0.001f;
                    j.y = bone.prev_joint.y * 0.001f;
                    j.z = bone.prev_joint.z * 0.001f;
                    j.qx = bone.rotation.x;
                    j.qy = bone.rotation.y;
                    j.qz = bone.rotation.z;
                    j.qw = bone.rotation.w;
                    j.confidence = lh.confidence;
                }

                // Tip = distal bone's next_joint
                DepthSensorJoint &tip = hand.fingers[f].bones[4];
                tip.joint_id = f * 5 + 4;
                tip.x = digit.distal.next_joint.x * 0.001f;
                tip.y = digit.distal.next_joint.y * 0.001f;
                tip.z = digit.distal.next_joint.z * 0.001f;
                tip.qx = digit.distal.rotation.x;
                tip.qy = digit.distal.rotation.y;
                tip.qz = digit.distal.rotation.z;
                tip.qw = digit.distal.rotation.w;
                tip.confidence = lh.confidence;
            }

            out.push_back(hand);
        }
    }

private:
    LEAP_CONNECTION m_connection = nullptr;
    const LEAP_TRACKING_EVENT *m_last_frame = nullptr;
    std::string m_serial;
    bool m_open = false;
    bool m_has_frame = false;
};


std::unique_ptr<DepthSensorBackend> create_ultraleap_backend() {
    return std::make_unique<UltraleapBackend>();
}

#else // GN_DEPTH_HAS_ULTRALEAP not defined

std::unique_ptr<DepthSensorBackend> create_ultraleap_backend() {
    return nullptr;
}

#endif
