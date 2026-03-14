#ifndef GN_SYPHON_CLIENT_H
#define GN_SYPHON_CLIENT_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

/// Wraps the Syphon Client API for receiving shared textures from other apps on macOS.
class GNSyphonClient : public RefCounted {
    GDCLASS(GNSyphonClient, RefCounted)

protected:
    static void _bind_methods();

public:
    GNSyphonClient();
    ~GNSyphonClient();

    bool connect_to_server(const String &app_name, const String &server_name);
    PackedByteArray receive_image();
    void disconnect();
    bool is_connected() const;
    int get_width() const;
    int get_height() const;
    static PackedStringArray get_server_list();

private:
#ifdef __APPLE__
    void *_syphon_client = nullptr; // SyphonClient* (Obj-C, stored as void*)
    void *_gl_context = nullptr;    // NSOpenGLContext*
    int _width = 0;
    int _height = 0;
#endif
};

} // namespace godot

#endif // GN_SYPHON_CLIENT_H
