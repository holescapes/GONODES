#include "gn_syphon_server.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#ifdef __APPLE__
#import <Syphon/Syphon.h>
#import <OpenGL/gl.h>
#import <AppKit/NSOpenGLContext.h>
#endif

namespace godot {

void GNSyphonServer::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_server_name", "name"), &GNSyphonServer::set_server_name);
    ClassDB::bind_method(D_METHOD("publish_image", "rgba_data", "width", "height"), &GNSyphonServer::publish_image);
    ClassDB::bind_method(D_METHOD("stop"), &GNSyphonServer::stop);
    ClassDB::bind_method(D_METHOD("is_running"), &GNSyphonServer::is_running);
    ClassDB::bind_method(D_METHOD("get_server_name"), &GNSyphonServer::get_server_name);
}

GNSyphonServer::GNSyphonServer() {
#ifdef __APPLE__
    _syphon_server = nullptr;
    _gl_context = nullptr;
#endif
}

GNSyphonServer::~GNSyphonServer() {
    stop();
}

void GNSyphonServer::set_server_name(const String &name) {
#ifdef __APPLE__
    // Stop existing server if name changes
    stop();

    // Create a shared OpenGL context for Syphon
    NSOpenGLPixelFormatAttribute attrs[] = {
        NSOpenGLPFAAccelerated,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAColorSize, 24,
        NSOpenGLPFAAlphaSize, 8,
        0
    };
    NSOpenGLPixelFormat *pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
    NSOpenGLContext *ctx = [[NSOpenGLContext alloc] initWithFormat:pf shareContext:nil];
    [ctx makeCurrentContext];

    _gl_context = (__bridge_retained void *)ctx;

    CharString name_utf8 = name.utf8();
    NSString *ns_name = [NSString stringWithUTF8String:name_utf8.get_data()];

    SyphonServer *server = [[SyphonServer alloc] initWithName:ns_name
                                                      context:ctx.CGLContextObj
                                                      options:nil];
    _syphon_server = (__bridge_retained void *)server;
#endif
}

bool GNSyphonServer::publish_image(const PackedByteArray &rgba_data, int width, int height) {
#ifdef __APPLE__
    if (_syphon_server == nullptr || _gl_context == nullptr) return false;

    int expected_size = width * height * 4;
    if (rgba_data.size() < expected_size) return false;

    SyphonServer *server = (__bridge SyphonServer *)_syphon_server;
    NSOpenGLContext *ctx = (__bridge NSOpenGLContext *)_gl_context;
    [ctx makeCurrentContext];

    // Upload RGBA data to a temporary GL texture
    GLuint tex = 0;
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0,
                 GL_RGBA, GL_UNSIGNED_BYTE, rgba_data.ptr());

    // Publish via Syphon — publishes the texture content as an IOSurface
    [server publishFrameTexture:tex
                  textureTarget:GL_TEXTURE_2D
                    imageRegion:NSMakeRect(0, 0, width, height)
              textureDimensions:NSMakeSize(width, height)
                        flipped:NO];

    glDeleteTextures(1, &tex);
    return true;
#else
    return false;
#endif
}

void GNSyphonServer::stop() {
#ifdef __APPLE__
    if (_syphon_server != nullptr) {
        SyphonServer *server = (__bridge_transfer SyphonServer *)_syphon_server;
        [server stop];
        _syphon_server = nullptr;
    }
    if (_gl_context != nullptr) {
        // Release the retained context
        NSOpenGLContext *ctx = (__bridge_transfer NSOpenGLContext *)_gl_context;
        (void)ctx; // ARC will release
        _gl_context = nullptr;
    }
#endif
}

bool GNSyphonServer::is_running() const {
#ifdef __APPLE__
    if (_syphon_server == nullptr) return false;
    SyphonServer *server = (__bridge SyphonServer *)_syphon_server;
    return server.hasClients || true; // Server is running if object exists
#else
    return false;
#endif
}

String GNSyphonServer::get_server_name() const {
#ifdef __APPLE__
    if (_syphon_server == nullptr) return "";
    SyphonServer *server = (__bridge SyphonServer *)_syphon_server;
    return String::utf8([server.name UTF8String]);
#else
    return "";
#endif
}

} // namespace godot
