#ifndef GN_VIDEO_CAPTURE_H
#define GN_VIDEO_CAPTURE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

/// Cross-platform video capture device wrapper.
/// Windows: Media Foundation, macOS: AVFoundation, Linux: V4L2.
class GNVideoCapture : public RefCounted {
    GDCLASS(GNVideoCapture, RefCounted)

protected:
    static void _bind_methods();

public:
    GNVideoCapture();
    ~GNVideoCapture();

    bool open_device(int device_index, int width, int height, int fps);
    void close_device();
    PackedByteArray capture_frame();
    bool is_open() const;
    int get_width() const;
    int get_height() const;

    static PackedStringArray get_device_list();
    static int get_device_count();

private:
    void *_impl = nullptr; // Platform-specific implementation handle
    int _width = 0;
    int _height = 0;
    bool _open = false;
};

} // namespace godot

#endif // GN_VIDEO_CAPTURE_H
