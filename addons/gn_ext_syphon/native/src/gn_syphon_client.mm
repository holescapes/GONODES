#include "gn_syphon_client.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#ifdef __APPLE__
#import <Syphon/Syphon.h>
#import <OpenGL/gl.h>
#import <AppKit/NSOpenGLContext.h>
#endif

namespace godot {

void GNSyphonClient::_bind_methods() {
    ClassDB::bind_method(D_METHOD("connect_to_server", "app_name", "server_name"), &GNSyphonClient::connect_to_server);
    ClassDB::bind_method(D_METHOD("receive_image"), &GNSyphonClient::receive_image);
    ClassDB::bind_method(D_METHOD("disconnect"), &GNSyphonClient::disconnect);
    ClassDB::bind_method(D_METHOD("is_connected"), &GNSyphonClient::is_connected);
    ClassDB::bind_method(D_METHOD("get_width"), &GNSyphonClient::get_width);
    ClassDB::bind_method(D_METHOD("get_height"), &GNSyphonClient::get_height);
    ClassDB::bind_static_method("GNSyphonClient", D_METHOD("get_server_list"), &GNSyphonClient::get_server_list);
}

GNSyphonClient::GNSyphonClient() {
#ifdef __APPLE__
    _syphon_client = nullptr;
    _gl_context = nullptr;
#endif
}

GNSyphonClient::~GNSyphonClient() {
    disconnect();
}

bool GNSyphonClient::connect_to_server(const String &app_name, const String &server_name) {
#ifdef __APPLE__
    disconnect();

    // Create a shared OpenGL context
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

    // Build server description dictionary for targeted connection
    CharString app_utf8 = app_name.utf8();
    CharString srv_utf8 = server_name.utf8();

    NSString *ns_app = [NSString stringWithUTF8String:app_utf8.get_data()];
    NSString *ns_srv = [NSString stringWithUTF8String:srv_utf8.get_data()];

    NSDictionary *desc = @{
        SyphonServerDescriptionAppNameKey: ns_app,
        SyphonServerDescriptionNameKey: ns_srv,
    };

    SyphonClient *client = [[SyphonClient alloc] initWithServerDescription:desc
                                                                   context:ctx.CGLContextObj
                                                                   options:nil
                                                               newFrameHandler:^(SyphonClient *c) {
        // Frame callback — we poll instead via receive_image()
    }];

    if (client == nil) return false;

    _syphon_client = (__bridge_retained void *)client;
    return true;
#else
    UtilityFunctions::push_warning("GNSyphonClient: Syphon is only available on macOS.");
    return false;
#endif
}

PackedByteArray GNSyphonClient::receive_image() {
    PackedByteArray result;
#ifdef __APPLE__
    if (_syphon_client == nullptr || _gl_context == nullptr) return result;

    SyphonClient *client = (__bridge SyphonClient *)_syphon_client;
    NSOpenGLContext *ctx = (__bridge NSOpenGLContext *)_gl_context;
    [ctx makeCurrentContext];

    SyphonImage *frame = [client newFrameImage];
    if (frame == nil) return result;

    NSSize size = frame.textureSize;
    _width = (int)size.width;
    _height = (int)size.height;

    if (_width <= 0 || _height <= 0) return result;

    // Read pixels from the Syphon texture into a CPU buffer
    GLuint tex = (GLuint)frame.textureName;
    int byte_count = _width * _height * 4;
    result.resize(byte_count);

    // Bind texture and read back via FBO
    GLuint fbo = 0;
    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_RECTANGLE_ARB, tex, 0);

    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE) {
        glReadPixels(0, 0, _width, _height, GL_RGBA, GL_UNSIGNED_BYTE, result.ptrw());
    } else {
        result.resize(0);
    }

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDeleteFramebuffers(1, &fbo);
#endif
    return result;
}

void GNSyphonClient::disconnect() {
#ifdef __APPLE__
    if (_syphon_client != nullptr) {
        SyphonClient *client = (__bridge_transfer SyphonClient *)_syphon_client;
        [client stop];
        _syphon_client = nullptr;
    }
    if (_gl_context != nullptr) {
        NSOpenGLContext *ctx = (__bridge_transfer NSOpenGLContext *)_gl_context;
        (void)ctx;
        _gl_context = nullptr;
    }
    _width = 0;
    _height = 0;
#endif
}

bool GNSyphonClient::is_connected() const {
#ifdef __APPLE__
    if (_syphon_client == nullptr) return false;
    SyphonClient *client = (__bridge SyphonClient *)_syphon_client;
    return client.isValid;
#else
    return false;
#endif
}

int GNSyphonClient::get_width() const {
#ifdef __APPLE__
    return _width;
#else
    return 0;
#endif
}

int GNSyphonClient::get_height() const {
#ifdef __APPLE__
    return _height;
#else
    return 0;
#endif
}

PackedStringArray GNSyphonClient::get_server_list() {
    PackedStringArray list;
#ifdef __APPLE__
    NSArray *servers = [[SyphonServerDirectory sharedDirectory] servers];
    for (NSDictionary *desc in servers) {
        NSString *app_name = desc[SyphonServerDescriptionAppNameKey];
        NSString *srv_name = desc[SyphonServerDescriptionNameKey];
        NSString *combined = [NSString stringWithFormat:@"%@ — %@", app_name, srv_name];
        list.push_back(String::utf8([combined UTF8String]));
    }
#endif
    return list;
}

} // namespace godot
