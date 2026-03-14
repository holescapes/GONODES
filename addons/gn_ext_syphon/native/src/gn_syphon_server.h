#ifndef GN_SYPHON_SERVER_H
#define GN_SYPHON_SERVER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

/// Wraps the Syphon Server API for sharing textures to other applications on macOS.
/// Call set_server_name() once, then publish_image() each frame.
class GNSyphonServer : public RefCounted {
    GDCLASS(GNSyphonServer, RefCounted)

protected:
    static void _bind_methods();

public:
    GNSyphonServer();
    ~GNSyphonServer();

    void set_server_name(const String &name);
    bool publish_image(const PackedByteArray &rgba_data, int width, int height);
    void stop();
    bool is_running() const;
    String get_server_name() const;

private:
#ifdef __APPLE__
    void *_syphon_server = nullptr; // SyphonServer* (Obj-C, stored as void*)
    void *_gl_context = nullptr;    // NSOpenGLContext*
#endif
};

} // namespace godot

#endif // GN_SYPHON_SERVER_H
