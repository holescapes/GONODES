#include "gn_ndi_sender.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <Processing.NDI.Lib.h>

using namespace godot;

// ── Binding ──────────────────────────────────────────────────────────

void GNNDISender::_bind_methods() {
    ClassDB::bind_method(D_METHOD("create_sender", "name"), &GNNDISender::create_sender);
    ClassDB::bind_method(D_METHOD("release"), &GNNDISender::release);
    ClassDB::bind_method(D_METHOD("is_active"), &GNNDISender::is_active);

    ClassDB::bind_method(D_METHOD("send_video", "rgba", "width", "height", "fps_n", "fps_d"),
                         &GNNDISender::send_video, DEFVAL(30), DEFVAL(1));
    ClassDB::bind_method(D_METHOD("send_audio", "samples", "channels", "sample_rate", "num_samples"),
                         &GNNDISender::send_audio);

    ClassDB::bind_method(D_METHOD("get_name"), &GNNDISender::get_name);
    ClassDB::bind_method(D_METHOD("get_num_connections"), &GNNDISender::get_num_connections);
}

// ── Constructor / Destructor ─────────────────────────────────────────

GNNDISender::GNNDISender() {
    if (!NDIlib_initialize()) {
        UtilityFunctions::printerr("[GNNDISender] Failed to initialize NDI runtime.");
    }
}

GNNDISender::~GNNDISender() {
    release();
    NDIlib_destroy();
}

// ── Lifecycle ────────────────────────────────────────────────────────

void GNNDISender::create_sender(const String &p_name) {
    release();

    NDIlib_send_create_t send_desc;
    CharString name_utf8 = p_name.utf8();
    send_desc.p_ndi_name = name_utf8.get_data();
    send_desc.p_groups = nullptr;
    send_desc.clock_video = true;
    send_desc.clock_audio = true;

    m_sender = NDIlib_send_create(&send_desc);
    if (!m_sender) {
        UtilityFunctions::printerr("[GNNDISender] Failed to create NDI sender.");
        return;
    }
    m_name = p_name;
}

void GNNDISender::release() {
    if (m_sender) {
        NDIlib_send_destroy(m_sender);
        m_sender = nullptr;
    }
    m_name = "";
}

bool GNNDISender::is_active() const {
    return m_sender != nullptr;
}

// ── Video ────────────────────────────────────────────────────────────

void GNNDISender::send_video(const PackedByteArray &p_rgba, int p_width, int p_height,
                              int p_fps_n, int p_fps_d) {
    if (!m_sender) return;

    int64_t expected = static_cast<int64_t>(p_width) * p_height * 4;
    if (p_rgba.size() != expected) {
        UtilityFunctions::printerr("[GNNDISender] send_video: buffer size mismatch. Expected ",
                                   expected, " got ", p_rgba.size());
        return;
    }

    NDIlib_video_frame_v2_t frame;
    frame.xres = p_width;
    frame.yres = p_height;
    frame.FourCC = NDIlib_FourCC_type_RGBA;
    frame.frame_rate_N = p_fps_n;
    frame.frame_rate_D = p_fps_d;
    frame.picture_aspect_ratio = 0.0f; // square pixels
    frame.frame_format_type = NDIlib_frame_format_type_progressive;
    frame.timecode = NDIlib_send_timecode_synthesize;
    frame.p_data = const_cast<uint8_t *>(p_rgba.ptr());
    frame.line_stride_in_bytes = p_width * 4;
    frame.p_metadata = nullptr;
    frame.timestamp = 0;

    NDIlib_send_send_video_v2(m_sender, &frame);
}

// ── Audio ────────────────────────────────────────────────────────────

void GNNDISender::send_audio(const PackedFloat32Array &p_samples, int p_channels,
                              int p_sample_rate, int p_num_samples) {
    if (!m_sender) return;

    int64_t expected = static_cast<int64_t>(p_channels) * p_num_samples;
    if (p_samples.size() != expected) {
        UtilityFunctions::printerr("[GNNDISender] send_audio: buffer size mismatch. Expected ",
                                   expected, " got ", p_samples.size());
        return;
    }

    // NDI expects interleaved float audio via the _v3 API.
    NDIlib_audio_frame_interleaved_32f_t interleaved;
    interleaved.sample_rate = p_sample_rate;
    interleaved.no_channels = p_channels;
    interleaved.no_samples = p_num_samples;
    interleaved.timecode = NDIlib_send_timecode_synthesize;
    interleaved.p_data = const_cast<float *>(p_samples.ptr());

    NDIlib_util_send_send_audio_interleaved_32f(m_sender, &interleaved);
}

// ── Info ─────────────────────────────────────────────────────────────

String GNNDISender::get_name() const { return m_name; }

int GNNDISender::get_num_connections() const {
    if (!m_sender) return 0;
    return NDIlib_send_get_no_connections(m_sender, 0);
}
