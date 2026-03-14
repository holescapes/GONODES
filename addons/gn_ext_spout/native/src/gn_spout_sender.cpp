#include "gn_spout_sender.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#ifdef _WIN32
#include "SpoutSender.h"
#endif

namespace godot {

void GNSpoutSender::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_sender_name", "name"), &GNSpoutSender::set_sender_name);
    ClassDB::bind_method(D_METHOD("send_image", "rgba_data", "width", "height", "invert"), &GNSpoutSender::send_image, DEFVAL(false));
    ClassDB::bind_method(D_METHOD("release_sender"), &GNSpoutSender::release_sender);
    ClassDB::bind_method(D_METHOD("is_initialized"), &GNSpoutSender::is_initialized);
    ClassDB::bind_method(D_METHOD("get_sender_name"), &GNSpoutSender::get_sender_name);
    ClassDB::bind_method(D_METHOD("get_width"), &GNSpoutSender::get_width);
    ClassDB::bind_method(D_METHOD("get_height"), &GNSpoutSender::get_height);
}

GNSpoutSender::GNSpoutSender() {
#ifdef _WIN32
    _spout_sender = new SpoutSender();
#endif
}

GNSpoutSender::~GNSpoutSender() {
    release_sender();
}

void GNSpoutSender::set_sender_name(const String &name) {
#ifdef _WIN32
    if (_spout_sender == nullptr) return;
    auto *sender = static_cast<SpoutSender *>(_spout_sender);
    CharString name_utf8 = name.utf8();
    sender->SetSenderName(name_utf8.get_data());
#endif
}

bool GNSpoutSender::send_image(const PackedByteArray &rgba_data, int width, int height, bool invert) {
#ifdef _WIN32
    if (_spout_sender == nullptr) return false;
    auto *sender = static_cast<SpoutSender *>(_spout_sender);

    int expected_size = width * height * 4;
    if (rgba_data.size() < expected_size) return false;

    return sender->SendImage(rgba_data.ptr(), (unsigned int)width, (unsigned int)height, GL_RGBA, invert);
#else
    return false;
#endif
}

void GNSpoutSender::release_sender() {
#ifdef _WIN32
    if (_spout_sender != nullptr) {
        auto *sender = static_cast<SpoutSender *>(_spout_sender);
        sender->ReleaseSender();
        delete sender;
        _spout_sender = nullptr;
    }
#endif
}

bool GNSpoutSender::is_initialized() const {
#ifdef _WIN32
    if (_spout_sender == nullptr) return false;
    auto *sender = static_cast<SpoutSender *>(_spout_sender);
    return sender->IsInitialized();
#else
    return false;
#endif
}

String GNSpoutSender::get_sender_name() const {
#ifdef _WIN32
    if (_spout_sender == nullptr) return "";
    auto *sender = static_cast<SpoutSender *>(_spout_sender);
    const char *name = sender->GetName();
    return name ? String::utf8(name) : String("");
#else
    return "";
#endif
}

int GNSpoutSender::get_width() const {
#ifdef _WIN32
    if (_spout_sender == nullptr) return 0;
    auto *sender = static_cast<SpoutSender *>(_spout_sender);
    return (int)sender->GetWidth();
#else
    return 0;
#endif
}

int GNSpoutSender::get_height() const {
#ifdef _WIN32
    if (_spout_sender == nullptr) return 0;
    auto *sender = static_cast<SpoutSender *>(_spout_sender);
    return (int)sender->GetHeight();
#else
    return 0;
#endif
}

} // namespace godot
