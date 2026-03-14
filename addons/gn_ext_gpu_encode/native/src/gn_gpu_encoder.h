#ifndef GN_GPU_ENCODER_H
#define GN_GPU_ENCODER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

/// Hardware-accelerated video encoder.
/// Windows: Media Foundation (MF Sink Writer with H.264 MFT).
/// macOS: VideoToolbox (VTCompressionSession with H.264/H.265).
class GNGpuEncoder : public RefCounted {
    GDCLASS(GNGpuEncoder, RefCounted)

protected:
    static void _bind_methods();

public:
    GNGpuEncoder();
    ~GNGpuEncoder();

    /// Start encoding to the given file path.
    bool start(const String &file_path, int width, int height, int fps, int bitrate_kbps);
    /// Encode one RGBA frame.
    bool encode_frame(const PackedByteArray &rgba_data);
    /// Finalize and close the output file.
    void finish();
    /// Whether encoding is in progress.
    bool is_encoding() const;
    /// Number of frames encoded so far.
    int get_frame_count() const;

private:
    void *_impl = nullptr;
    int _width = 0;
    int _height = 0;
    int _fps = 0;
    int _frame_count = 0;
    bool _encoding = false;
};

} // namespace godot

#endif // GN_GPU_ENCODER_H
