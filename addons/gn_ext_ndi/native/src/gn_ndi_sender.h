#ifndef GN_NDI_SENDER_H
#define GN_NDI_SENDER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/string.hpp>

typedef struct NDIlib_send_instance_type *NDIlib_send_instance_t;

using namespace godot;

/// Sends video frames and audio samples to the NDI network
/// so that any NDI receiver application can pick them up.
///
/// GDScript usage (from operator):
///   var ndi = ClassDB.instantiate("GNNDISender")
///   ndi.create_sender("GoNodes Output")
///   ndi.send_video(rgba_bytes, width, height)
///   ndi.send_audio(float_samples, channels, sample_rate, num_samples)
///   ndi.release()
class GNNDISender : public RefCounted {
    GDCLASS(GNNDISender, RefCounted);

protected:
    static void _bind_methods();

public:
    GNNDISender();
    ~GNNDISender();

    // ── Sender Lifecycle ─────────────────────────────────────────────
    /// Create a named NDI sender visible on the network.
    void create_sender(const String &p_name);

    /// Destroy the sender, freeing all NDI resources.
    void release();

    /// Returns true if the sender is active.
    bool is_active() const;

    // ── Video ────────────────────────────────────────────────────────
    /// Send one RGBA8 video frame (width × height × 4 bytes).
    /// [param p_fps_n]: frame-rate numerator   (e.g. 30000)
    /// [param p_fps_d]: frame-rate denominator (e.g. 1001)
    void send_video(const PackedByteArray &p_rgba, int p_width, int p_height,
                    int p_fps_n = 30, int p_fps_d = 1);

    // ── Audio ────────────────────────────────────────────────────────
    /// Send interleaved float audio samples.
    /// [param p_samples]: interleaved float array (channels × num_samples)
    /// [param p_channels]: number of audio channels
    /// [param p_sample_rate]: sample rate in Hz (e.g. 48000)
    /// [param p_num_samples]: number of samples per channel
    void send_audio(const PackedFloat32Array &p_samples, int p_channels,
                    int p_sample_rate, int p_num_samples);

    // ── Info ─────────────────────────────────────────────────────────
    /// The registered sender name.
    String get_name() const;

    /// Number of receivers currently connected to this sender.
    int get_num_connections() const;

private:
    NDIlib_send_instance_t m_sender = nullptr;
    String m_name;
};

#endif // GN_NDI_SENDER_H
