#include "gn_ndi_receiver.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

// ── NDI SDK ──────────────────────────────────────────────────────────
// Users must download the NDI SDK from https://ndi.video/download-ndi-sdk/
// and place it in  addons/gn_ext_ndi/native/ndi_sdk/
#include <Processing.NDI.Lib.h>

using namespace godot;

// ── Binding ──────────────────────────────────────────────────────────

void GNNDIReceiver::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_source_list"), &GNNDIReceiver::get_source_list);
    ClassDB::bind_method(D_METHOD("get_source_count"), &GNNDIReceiver::get_source_count);

    ClassDB::bind_method(D_METHOD("create_receiver", "source_name", "bandwidth"), &GNNDIReceiver::create_receiver, DEFVAL(0));
    ClassDB::bind_method(D_METHOD("release"), &GNNDIReceiver::release);
    ClassDB::bind_method(D_METHOD("is_receiver_connected"), &GNNDIReceiver::is_receiver_connected);

    ClassDB::bind_method(D_METHOD("receive_video", "timeout_ms"), &GNNDIReceiver::receive_video, DEFVAL(16));
    ClassDB::bind_method(D_METHOD("get_video_width"), &GNNDIReceiver::get_video_width);
    ClassDB::bind_method(D_METHOD("get_video_height"), &GNNDIReceiver::get_video_height);
    ClassDB::bind_method(D_METHOD("get_video_fps_n"), &GNNDIReceiver::get_video_fps_n);
    ClassDB::bind_method(D_METHOD("get_video_fps_d"), &GNNDIReceiver::get_video_fps_d);

    ClassDB::bind_method(D_METHOD("receive_audio", "timeout_ms"), &GNNDIReceiver::receive_audio, DEFVAL(16));
    ClassDB::bind_method(D_METHOD("get_audio_channels"), &GNNDIReceiver::get_audio_channels);
    ClassDB::bind_method(D_METHOD("get_audio_sample_rate"), &GNNDIReceiver::get_audio_sample_rate);
    ClassDB::bind_method(D_METHOD("get_audio_num_samples"), &GNNDIReceiver::get_audio_num_samples);

    ClassDB::bind_method(D_METHOD("get_source_name"), &GNNDIReceiver::get_source_name);
}

// ── Constructor / Destructor ─────────────────────────────────────────

GNNDIReceiver::GNNDIReceiver() {
    if (!NDIlib_initialize()) {
        UtilityFunctions::printerr("[GNNDIReceiver] Failed to initialize NDI runtime.");
    }
}

GNNDIReceiver::~GNNDIReceiver() {
    release();
    _destroy_finder();
    NDIlib_destroy();
}

// ── Internal Helpers ─────────────────────────────────────────────────

void GNNDIReceiver::_ensure_finder() {
    if (m_finder) return;
    NDIlib_find_create_t find_desc;
    find_desc.show_local_sources = true;
    find_desc.p_groups = nullptr;
    find_desc.p_extra_ips = nullptr;
    m_finder = NDIlib_find_create_v2(&find_desc);
    if (!m_finder) {
        UtilityFunctions::printerr("[GNNDIReceiver] Failed to create NDI finder.");
    }
}

void GNNDIReceiver::_destroy_finder() {
    if (m_finder) {
        NDIlib_find_destroy(m_finder);
        m_finder = nullptr;
    }
}

// ── Discovery ────────────────────────────────────────────────────────

PackedStringArray GNNDIReceiver::get_source_list() {
    PackedStringArray result;
    _ensure_finder();
    if (!m_finder) return result;

    // Allow brief network scan (100 ms).
    NDIlib_find_wait_for_sources(m_finder, 100);

    uint32_t count = 0;
    const NDIlib_source_t *sources = NDIlib_find_get_current_sources(m_finder, &count);
    for (uint32_t i = 0; i < count; i++) {
        result.push_back(String::utf8(sources[i].p_ndi_name));
    }
    return result;
}

int GNNDIReceiver::get_source_count() {
    return get_source_list().size();
}

// ── Receiver Lifecycle ───────────────────────────────────────────────

void GNNDIReceiver::create_receiver(const String &p_source_name, int p_bandwidth) {
    release(); // Disconnect any previous.
    _ensure_finder();

    // Find the source matching the requested name.
    NDIlib_find_wait_for_sources(m_finder, 500);

    uint32_t count = 0;
    const NDIlib_source_t *sources = NDIlib_find_get_current_sources(m_finder, &count);

    const NDIlib_source_t *target = nullptr;
    CharString name_utf8 = p_source_name.utf8();
    for (uint32_t i = 0; i < count; i++) {
        if (strcmp(sources[i].p_ndi_name, name_utf8.get_data()) == 0) {
            target = &sources[i];
            break;
        }
    }

    if (!target) {
        UtilityFunctions::printerr("[GNNDIReceiver] Source not found: ", p_source_name);
        return;
    }

    NDIlib_recv_create_v3_t recv_desc;
    recv_desc.source_to_connect_to = *target;
    recv_desc.color_format = NDIlib_recv_color_format_RGBX_RGBA;
    recv_desc.allow_video_fields = false;
    recv_desc.p_ndi_recv_name = "GoNodes NDI Receiver";

    switch (p_bandwidth) {
        case 1: recv_desc.bandwidth = NDIlib_recv_bandwidth_audio_only; break;
        case 2: recv_desc.bandwidth = NDIlib_recv_bandwidth_lowest; break;
        default: recv_desc.bandwidth = NDIlib_recv_bandwidth_highest; break;
    }

    m_receiver = NDIlib_recv_create_v3(&recv_desc);
    if (!m_receiver) {
        UtilityFunctions::printerr("[GNNDIReceiver] Failed to create NDI receiver.");
        return;
    }

    m_source_name = p_source_name;
}

void GNNDIReceiver::release() {
    if (m_receiver) {
        NDIlib_recv_destroy(m_receiver);
        m_receiver = nullptr;
    }
    m_source_name = "";
    m_video_width = 0;
    m_video_height = 0;
    m_audio_channels = 0;
    m_audio_num_samples = 0;
}

bool GNNDIReceiver::is_receiver_connected() const {
    return m_receiver != nullptr;
}

// ── Video ────────────────────────────────────────────────────────────

PackedByteArray GNNDIReceiver::receive_video(int p_timeout_ms) {
    PackedByteArray result;
    if (!m_receiver) return result;

    NDIlib_video_frame_v2_t video_frame;
    NDIlib_audio_frame_v3_t audio_frame;
    NDIlib_metadata_frame_t metadata_frame;

    switch (NDIlib_recv_capture_v3(m_receiver, &video_frame, nullptr, nullptr, static_cast<uint32_t>(p_timeout_ms))) {
        case NDIlib_frame_type_video: {
            m_video_width = video_frame.xres;
            m_video_height = video_frame.yres;
            m_video_fps_n = video_frame.frame_rate_N;
            m_video_fps_d = video_frame.frame_rate_D;

            int64_t byte_count = static_cast<int64_t>(m_video_width) * m_video_height * 4;
            result.resize(byte_count);

            // NDI delivers RGBA when we requested NDIlib_recv_color_format_RGBX_RGBA.
            // Copy row-by-row in case stride differs from width * 4.
            uint8_t *dst = result.ptrw();
            const uint8_t *src = video_frame.p_data;
            int row_bytes = m_video_width * 4;
            for (int y = 0; y < m_video_height; y++) {
                memcpy(dst + y * row_bytes, src + y * video_frame.line_stride_in_bytes, row_bytes);
            }

            NDIlib_recv_free_video_v2(m_receiver, &video_frame);
            break;
        }
        default:
            break;
    }
    return result;
}

int GNNDIReceiver::get_video_width() const { return m_video_width; }
int GNNDIReceiver::get_video_height() const { return m_video_height; }
int GNNDIReceiver::get_video_fps_n() const { return m_video_fps_n; }
int GNNDIReceiver::get_video_fps_d() const { return m_video_fps_d; }

// ── Audio ────────────────────────────────────────────────────────────

PackedFloat32Array GNNDIReceiver::receive_audio(int p_timeout_ms) {
    PackedFloat32Array result;
    if (!m_receiver) return result;

    NDIlib_audio_frame_v3_t audio_frame;

    switch (NDIlib_recv_capture_v3(m_receiver, nullptr, &audio_frame, nullptr, static_cast<uint32_t>(p_timeout_ms))) {
        case NDIlib_frame_type_audio: {
            m_audio_channels = audio_frame.no_channels;
            m_audio_sample_rate = audio_frame.sample_rate;
            m_audio_num_samples = audio_frame.no_samples;

            // Convert to interleaved float via NDI utility.
            NDIlib_audio_frame_interleaved_32f_t interleaved;
            interleaved.sample_rate = audio_frame.sample_rate;
            interleaved.no_channels = audio_frame.no_channels;
            interleaved.no_samples = audio_frame.no_samples;

            int total_samples = m_audio_channels * m_audio_num_samples;
            result.resize(total_samples);
            interleaved.p_data = result.ptrw();

            NDIlib_util_audio_to_interleaved_32f_v3(&audio_frame, &interleaved);
            NDIlib_recv_free_audio_v3(m_receiver, &audio_frame);
            break;
        }
        default:
            break;
    }
    return result;
}

int GNNDIReceiver::get_audio_channels() const { return m_audio_channels; }
int GNNDIReceiver::get_audio_sample_rate() const { return m_audio_sample_rate; }
int GNNDIReceiver::get_audio_num_samples() const { return m_audio_num_samples; }

// ── Source Info ──────────────────────────────────────────────────────

String GNNDIReceiver::get_source_name() const { return m_source_name; }
