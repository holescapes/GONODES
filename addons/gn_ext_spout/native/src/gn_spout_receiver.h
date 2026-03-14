#ifndef GN_SPOUT_RECEIVER_H
#define GN_SPOUT_RECEIVER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

/// Wraps the Spout2 receiver API for receiving shared textures from other apps.
class GNSpoutReceiver : public RefCounted {
    GDCLASS(GNSpoutReceiver, RefCounted)

protected:
    static void _bind_methods();

public:
    GNSpoutReceiver();
    ~GNSpoutReceiver();

    bool create_receiver(const String &name);
    PackedByteArray receive_image();
    void release_receiver();
    bool is_initialized() const;
    bool is_updated() const;
    String get_sender_name() const;
    int get_width() const;
    int get_height() const;
    PackedStringArray get_sender_list() const;
    int get_sender_count() const;

private:
#ifdef _WIN32
    void *_spout_receiver = nullptr; // SpoutReceiver*
    bool _initialized = false;
    String _sender_name;
    int _width = 0;
    int _height = 0;
#endif
};

} // namespace godot

#endif // GN_SPOUT_RECEIVER_H
