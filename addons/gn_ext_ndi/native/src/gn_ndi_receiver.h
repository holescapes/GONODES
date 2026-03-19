#ifndef GN_NDI_RECEIVER_H
#define GN_NDI_RECEIVER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/string.hpp>

// Forward-declare NDI types to avoid requiring the header at parse time.
// The actual NDI SDK header is included only in the .cpp file.
typedef struct NDIlib_recv_instance_type *NDIlib_recv_instance_t;
typedef struct NDIlib_find_instance_type *NDIlib_find_instance_t;

using namespace godot;

/// Receives NDI video frames and audio samples from any NDI source
/// discovered on the local network.
///
/// GDScript usage (from operator):
///   var ndi = ClassDB.instantiate("GNNDIReceiver")
///   ndi.create_receiver("MY_SOURCE (hostname)")
///   var rgba = ndi.receive_video()     // PackedByteArray RGBA8
///   var audio = ndi.receive_audio()    // PackedFloat32Array interleaved
///   ndi.release()
class GNNDIReceiver : public RefCounted {
    GDCLASS(GNNDIReceiver, RefCounted);

protected:
    static void _bind_methods();

public:
    GNNDIReceiver();
    ~GNNDIReceiver();

    // ── Discovery ────────────────────────────────────────────────────
    /// Returns a PackedStringArray of all NDI source names currently
    /// visible on the network.  Performs a brief network scan each call.
    PackedStringArray get_source_list();

    /// Returns the number of sources found in the last scan.
    int get_source_count();

    // ── Receiver Lifecycle ───────────────────────────────────────────
    /// Connect to a named NDI source.  Pass the full name string
    /// returned by get_source_list() (e.g. "OBS (DESKTOP-ABC)").
    /// [param bandwidth]: 0 = highest, 1 = lowest (audio-only), 2 = same as source
    void create_receiver(const String &p_source_name, int p_bandwidth = 0);

    /// Disconnect and free the receiver instance.
    void release();

    /// Returns true if a receiver is currently connected.
    bool is_receiver_connected() const;

    // ── Video ────────────────────────────────────────────────────────
    /// Capture one video frame.  Returns RGBA8 pixel data as a
    /// PackedByteArray (width × height × 4 bytes), or empty if no
    /// frame is available within the timeout.
    /// [param timeout_ms]: milliseconds to wait for a frame (0 = no wait)
    PackedByteArray receive_video(int p_timeout_ms = 16);

    /// Width / height of the most recently received video frame.
    int get_video_width() const;
    int get_video_height() const;

    /// Frame rate of the incoming stream (numerator / denominator).
    int get_video_fps_n() const;
    int get_video_fps_d() const;

    // ── Audio ────────────────────────────────────────────────────────
    /// Capture one audio buffer.  Returns interleaved float samples
    /// as a PackedFloat32Array (channels × samples_per_channel).
    /// [param timeout_ms]: milliseconds to wait (0 = no wait)
    PackedFloat32Array receive_audio(int p_timeout_ms = 16);

    /// Number of audio channels in the most recent audio frame.
    int get_audio_channels() const;

    /// Audio sample rate (Hz) of the most recent audio frame.
    int get_audio_sample_rate() const;

    /// Number of samples per channel in the most recent audio frame.
    int get_audio_num_samples() const;

    // ── Source Info ──────────────────────────────────────────────────
    /// The name of the currently connected source.
    String get_source_name() const;

private:
    NDIlib_find_instance_t m_finder = nullptr;
    NDIlib_recv_instance_t m_receiver = nullptr;
    String m_source_name;

    int m_video_width = 0;
    int m_video_height = 0;
    int m_video_fps_n = 30;
    int m_video_fps_d = 1;

    int m_audio_channels = 0;
    int m_audio_sample_rate = 48000;
    int m_audio_num_samples = 0;

    void _ensure_finder();
    void _destroy_finder();
};

#endif // GN_NDI_RECEIVER_H
