#include "depth_sensor_backend.h"

// Intel RealSense SDK (librealsense2) — only when building with RealSense support.
#ifdef GN_DEPTH_HAS_REALSENSE

#include <librealsense2/rs.hpp>

#include <cstring>
#include <algorithm>

class RealSenseBackend : public DepthSensorBackend {
public:
    ~RealSenseBackend() override { close(); }

    std::string get_backend_name() const override { return "RealSense D400"; }

    uint32_t get_capabilities() const override {
        // RealSense D400 series: depth + color + IR + point cloud
        // No hardware skeleton tracking, no player index, no floor plane
        return CAP_DEPTH | CAP_COLOR | CAP_IR | CAP_POINT_CLOUD;
    }

    std::vector<DeviceInfo> enumerate_devices() override {
        std::vector<DeviceInfo> result;
        rs2::context ctx;
        auto devices = ctx.query_devices();
        for (int i = 0; i < static_cast<int>(devices.size()); i++) {
            auto dev = devices[i];
            DeviceInfo info;
            info.serial = dev.get_info(RS2_CAMERA_INFO_SERIAL_NUMBER);
            std::string name = dev.get_info(RS2_CAMERA_INFO_NAME);
            info.display_name = name + " (S/N: " + info.serial + ")";
            result.push_back(info);
        }
        return result;
    }

    bool open(const std::string &serial) override {
        close();
        try {
            rs2::config cfg;
            if (!serial.empty()) {
                cfg.enable_device(serial);
            }

            // Enable depth, color, and IR streams
            cfg.enable_stream(RS2_STREAM_DEPTH, 640, 480, RS2_FORMAT_Z16, 30);
            cfg.enable_stream(RS2_STREAM_COLOR, 640, 480, RS2_FORMAT_RGB8, 30);
            cfg.enable_stream(RS2_STREAM_INFRARED, 1, 640, 480, RS2_FORMAT_Y8, 30);

            m_profile = m_pipe.start(cfg);

            // Get depth scale for point cloud conversion
            auto depth_sensor = m_profile.get_device().first<rs2::depth_sensor>();
            m_depth_scale = depth_sensor.get_depth_scale(); // meters per unit

            m_open = true;
            return true;
        } catch (const rs2::error &e) {
            return false;
        }
    }

    void close() override {
        if (m_open) {
            try { m_pipe.stop(); } catch (...) {}
        }
        m_open = false;
        m_has_frame = false;
    }

    bool is_open() const override { return m_open; }

    bool capture(int timeout_ms) override {
        if (!m_open) return false;
        try {
            rs2::frameset frames;
            if (timeout_ms > 0) {
                if (!m_pipe.poll_for_frames(&frames)) {
                    // Try with timeout
                    frames = m_pipe.wait_for_frames(static_cast<unsigned int>(timeout_ms));
                }
            } else {
                if (!m_pipe.poll_for_frames(&frames))
                    return false;
            }

            // Align color to depth for consistent coordinate space
            rs2::align align(RS2_STREAM_DEPTH);
            m_frames = align.process(frames);
            m_has_frame = true;
            return true;
        } catch (const rs2::error &) {
            return false;
        }
    }

    // ── Depth ────────────────────────────────────────────────────────

    void get_depth_image(std::vector<uint8_t> &out, int &width, int &height) override {
        out.clear();
        width = height = 0;
        if (!m_has_frame) return;

        auto depth = m_frames.get_depth_frame();
        if (!depth) return;

        width = depth.get_width();
        height = depth.get_height();
        size_t size = static_cast<size_t>(width) * height * 2;
        out.resize(size);

        // RealSense Z16 is in sensor units — convert to millimeters
        const uint16_t *src = reinterpret_cast<const uint16_t *>(depth.get_data());
        uint16_t *dst = reinterpret_cast<uint16_t *>(out.data());
        float scale_to_mm = m_depth_scale * 1000.0f;

        for (int i = 0; i < width * height; i++) {
            // Convert from sensor units to millimeters
            dst[i] = static_cast<uint16_t>(std::min(65535.0f,
                static_cast<float>(src[i]) * scale_to_mm));
        }
    }

    // ── Color ────────────────────────────────────────────────────────

    void get_color_image(std::vector<uint8_t> &out, int &width, int &height) override {
        out.clear();
        width = height = 0;
        if (!m_has_frame) return;

        auto color = m_frames.get_color_frame();
        if (!color) return;

        width = color.get_width();
        height = color.get_height();
        int pixel_count = width * height;
        out.resize(static_cast<size_t>(pixel_count) * 4);

        // RGB8 → RGBA8
        const uint8_t *src = reinterpret_cast<const uint8_t *>(color.get_data());
        for (int i = 0; i < pixel_count; i++) {
            out[i * 4 + 0] = src[i * 3 + 0]; // R
            out[i * 4 + 1] = src[i * 3 + 1]; // G
            out[i * 4 + 2] = src[i * 3 + 2]; // B
            out[i * 4 + 3] = 255;             // A
        }
    }

    // ── IR ────────────────────────────────────────────────────────────

    void get_ir_image(std::vector<uint8_t> &out, int &width, int &height) override {
        out.clear();
        width = height = 0;
        if (!m_has_frame) return;

        auto ir = m_frames.get_infrared_frame();
        if (!ir) return;

        width = ir.get_width();
        height = ir.get_height();
        int pixel_count = width * height;
        out.resize(static_cast<size_t>(pixel_count) * 2);

        // RealSense IR is 8-bit Y8 — expand to 16-bit for uniform interface
        const uint8_t *src = reinterpret_cast<const uint8_t *>(ir.get_data());
        uint16_t *dst = reinterpret_cast<uint16_t *>(out.data());
        for (int i = 0; i < pixel_count; i++) {
            dst[i] = static_cast<uint16_t>(src[i]) << 2; // Scale 8-bit to ~10-bit range
        }
    }

    // ── Player Index (not supported) ─────────────────────────────────

    void get_player_index_image(std::vector<uint8_t> &out, int &width, int &height) override {
        out.clear();
        width = height = 0;
    }

    // ── Skeleton (not supported) ─────────────────────────────────────

    void get_bodies(std::vector<DepthSensorBody> &out) override {
        out.clear();
    }

    // ── Point Cloud ──────────────────────────────────────────────────

    void get_point_cloud(std::vector<float> &out) override {
        out.clear();
        if (!m_has_frame) return;

        auto depth = m_frames.get_depth_frame();
        if (!depth) return;

        rs2::pointcloud pc;
        rs2::points points = pc.calculate(depth);

        auto vertices = points.get_vertices();
        int count = static_cast<int>(points.size());

        out.resize(static_cast<size_t>(count) * 3);
        for (int i = 0; i < count; i++) {
            out[i * 3 + 0] = vertices[i].x;
            out[i * 3 + 1] = vertices[i].y;
            out[i * 3 + 2] = vertices[i].z;
        }
    }

    void get_point_cloud_colors(std::vector<uint8_t> &out) override {
        out.clear();
        if (!m_has_frame) return;

        auto depth = m_frames.get_depth_frame();
        auto color = m_frames.get_color_frame();
        if (!depth || !color) return;

        rs2::pointcloud pc;
        pc.map_to(color);
        rs2::points points = pc.calculate(depth);

        auto tex_coords = points.get_texture_coordinates();
        int count = static_cast<int>(points.size());
        int cw = color.get_width();
        int ch = color.get_height();
        const uint8_t *color_data = reinterpret_cast<const uint8_t *>(color.get_data());

        out.resize(static_cast<size_t>(count) * 4);
        for (int i = 0; i < count; i++) {
            int u = std::clamp(static_cast<int>(tex_coords[i].u * cw), 0, cw - 1);
            int v = std::clamp(static_cast<int>(tex_coords[i].v * ch), 0, ch - 1);
            int idx = (v * cw + u) * 3;
            out[i * 4 + 0] = color_data[idx + 0]; // R
            out[i * 4 + 1] = color_data[idx + 1]; // G
            out[i * 4 + 2] = color_data[idx + 2]; // B
            out[i * 4 + 3] = 255;                  // A
        }
    }

    // ── Floor Plane (not supported) ──────────────────────────────────

    bool get_floor_plane(float &nx, float &ny, float &nz, float &d) override {
        return false;
    }

    // ── Joint Names (not applicable) ─────────────────────────────────

    std::string get_joint_name(int joint_id) const override {
        return "unsupported";
    }

    int get_joint_count() const override { return 0; }

    // ── Hand tracking (not supported by RealSense) ──────────────────

    void get_hands(std::vector<DepthSensorHand> &out) override {
        out.clear();
    }

private:
    rs2::pipeline m_pipe;
    rs2::pipeline_profile m_profile;
    rs2::frameset m_frames;
    float m_depth_scale = 0.001f; // Default: 1mm per unit
    bool m_open = false;
    bool m_has_frame = false;
};


std::unique_ptr<DepthSensorBackend> create_realsense_backend() {
    return std::make_unique<RealSenseBackend>();
}

#else // GN_DEPTH_HAS_REALSENSE not defined

std::unique_ptr<DepthSensorBackend> create_realsense_backend() {
    return nullptr;
}

#endif
