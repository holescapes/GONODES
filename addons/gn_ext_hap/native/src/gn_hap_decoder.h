#ifndef GN_HAP_DECODER_H
#define GN_HAP_DECODER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <cstdint>
#include <cstdio>
#include <vector>

namespace godot {

/// HAP video decoder — reads .mov containers with HAP-encoded frames.
///
/// Returns raw DXT/S3TC block data per frame.  The caller uploads this
/// directly to the GPU via Image.FORMAT_DXT1 / FORMAT_DXT5 — no CPU
/// pixel-level decode step.
///
/// Supported variants:
///   HAP        — DXT1 (BC1), opaque, smallest size
///   HAP Alpha  — DXT5 (BC3), with alpha channel
///   HAP Q      — Scaled YCoCg DXT5, higher quality, larger
class GNHapDecoder : public RefCounted {
    GDCLASS(GNHapDecoder, RefCounted)

protected:
    static void _bind_methods();

public:
    GNHapDecoder();
    ~GNHapDecoder();

    /// Open a .mov file containing HAP-encoded video.
    /// Returns true on success.
    bool open(const String &file_path);

    /// Close the current file and free resources.
    void close();

    /// Decode the next frame and return raw DXT block data.
    /// Returns empty array on EOF or error.
    PackedByteArray decode_next_frame();

    /// Seek to a specific frame number (0-based).
    void seek_frame(int frame_index);

    /// Seek to a specific time in seconds.
    void seek_time(double seconds);

    /// Whether a file is currently open and valid.
    bool is_open() const;

    /// Video width in pixels.
    int get_width() const;

    /// Video height in pixels.
    int get_height() const;

    /// Frame rate (frames per second).
    double get_fps() const;

    /// Total number of frames in the video.
    int get_frame_count() const;

    /// Current frame index (0-based).
    int get_current_frame() const;

    /// Duration in seconds.
    double get_duration() const;

    /// HAP variant: 0=HAP (DXT1), 1=HAP Alpha (DXT5), 2=HAP Q (Scaled YCoCg DXT5).
    int get_hap_variant() const;

    /// Godot Image format constant matching the HAP variant.
    /// Returns Image::FORMAT_DXT1 (17), FORMAT_DXT5 (19), or FORMAT_DXT5 for HAP Q.
    int get_image_format() const;

    /// Size in bytes of one DXT-compressed frame.
    int get_compressed_frame_size() const;

private:
    // ── MOV Container Parsing ─────────────────────────────────────────────

    struct FrameEntry {
        int64_t offset;     // Byte offset in file
        int32_t size;       // Compressed chunk size
    };

    FILE *_file = nullptr;
    int _width = 0;
    int _height = 0;
    double _fps = 30.0;
    int _hap_variant = 0;          // 0=HAP, 1=HAP Alpha, 2=HAP Q
    int _current_frame = 0;
    std::vector<FrameEntry> _frame_table;

    // Scratch buffer for Snappy decompression
    std::vector<uint8_t> _scratch;

    bool _parse_mov_header();
    bool _read_hap_frame(const FrameEntry &entry, std::vector<uint8_t> &out_dxt);
};

} // namespace godot

#endif // GN_HAP_DECODER_H
