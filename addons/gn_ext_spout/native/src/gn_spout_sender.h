#ifndef GN_SPOUT_SENDER_H
#define GN_SPOUT_SENDER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

#ifdef _WIN32
struct SPOUTLIBRARY; // Forward declare the Spout library class
#endif

namespace godot {

/// Wraps the Spout2 sender API for sharing textures to other applications.
/// Call create_sender() once, then send_image() each frame.
class GNSpoutSender : public RefCounted {
    GDCLASS(GNSpoutSender, RefCounted)

protected:
    static void _bind_methods();

public:
    GNSpoutSender();
    ~GNSpoutSender();

    void set_sender_name(const String &name);
    bool send_image(const PackedByteArray &rgba_data, int width, int height, bool invert = false);
    void release_sender();
    bool is_initialized() const;
    String get_sender_name() const;
    int get_width() const;
    int get_height() const;

private:
#ifdef _WIN32
    void *_spout_sender = nullptr; // SpoutSender*
#endif
};

} // namespace godot

#endif // GN_SPOUT_SENDER_H
