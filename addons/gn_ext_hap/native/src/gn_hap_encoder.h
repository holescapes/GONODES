#ifndef GN_HAP_ENCODER_H
#define GN_HAP_ENCODER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <cstdint>
#include <cstdio>
#include <vector>

namespace godot {

/// HAP video encoder — writes .mov containers with GPU-direct DXT frames.
///
/// Workflow:
///   1. start(path, width, height, fps, variant)
///   2. encode_frame(rgba_data)  — called once per frame
///   3. finish()  — finalizes the .mov container
///
/// RGBA pixel data is DXT-compressed on the CPU via squish, then optionally
/// Snappy-compressed and written as HAP atoms in a QuickTime MOV container.
class GNHapEncoder : public RefCounted {
    GDCLASS(GNHapEncoder, RefCounted)

protected:
    static void _bind_methods();

public:
    GNHapEncoder();
    ~GNHapEncoder();

    /// Start encoding.
    /// @param variant 0=HAP (DXT1), 1=HAP Alpha (DXT5), 2=HAP Q (YCoCg DXT5)
    bool start(const String &file_path, int width, int height, double fps, int variant);

    /// Encode one RGBA8 frame (width*height*4 bytes).
    bool encode_frame(const PackedByteArray &rgba_data);

    /// Finalize the MOV container and close the file.
    void finish();

    /// Whether encoding is in progress.
    bool is_encoding() const;

    /// Number of frames encoded so far.
    int get_frame_count() const;

private:
    FILE *_file = nullptr;
    int _width = 0;
    int _height = 0;
    double _fps = 30.0;
    int _variant = 0;
    int _frame_count = 0;
    bool _encoding = false;

    // Per-frame bookkeeping for MOV mdat → moov index
    struct FrameRecord {
        int64_t offset;  // Offset in mdat
        int32_t size;    // Compressed HAP chunk size
    };
    std::vector<FrameRecord> _frames;
    int64_t _mdat_start = 0;

    // Scratch buffers
    std::vector<uint8_t> _dxt_buf;
    std::vector<uint8_t> _snap_buf;

    void _write_u32_be(uint32_t v);
    void _write_u16_be(uint16_t v);
    void _write_u64_be(uint64_t v);
    void _write_fourcc(const char *cc);
    void _write_moov_atom();
};

} // namespace godot

#endif // GN_HAP_ENCODER_H
