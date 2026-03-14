#include "gn_spout_receiver.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#ifdef _WIN32
#include "SpoutReceiver.h"
#include <vector>
#include <string>
#endif

namespace godot {

void GNSpoutReceiver::_bind_methods() {
    ClassDB::bind_method(D_METHOD("create_receiver", "name"), &GNSpoutReceiver::create_receiver);
    ClassDB::bind_method(D_METHOD("receive_image"), &GNSpoutReceiver::receive_image);
    ClassDB::bind_method(D_METHOD("release_receiver"), &GNSpoutReceiver::release_receiver);
    ClassDB::bind_method(D_METHOD("is_initialized"), &GNSpoutReceiver::is_initialized);
    ClassDB::bind_method(D_METHOD("is_updated"), &GNSpoutReceiver::is_updated);
    ClassDB::bind_method(D_METHOD("get_sender_name"), &GNSpoutReceiver::get_sender_name);
    ClassDB::bind_method(D_METHOD("get_width"), &GNSpoutReceiver::get_width);
    ClassDB::bind_method(D_METHOD("get_height"), &GNSpoutReceiver::get_height);
    ClassDB::bind_method(D_METHOD("get_sender_list"), &GNSpoutReceiver::get_sender_list);
    ClassDB::bind_method(D_METHOD("get_sender_count"), &GNSpoutReceiver::get_sender_count);
}

GNSpoutReceiver::GNSpoutReceiver() {
#ifdef _WIN32
    _spout_receiver = nullptr;
    _initialized = false;
#endif
}

GNSpoutReceiver::~GNSpoutReceiver() {
    release_receiver();
}

bool GNSpoutReceiver::create_receiver(const String &name) {
#ifdef _WIN32
    release_receiver();

    auto *receiver = new SpoutReceiver();
    CharString name_utf8 = name.utf8();

    // SetReceiverName to target a specific sender (empty = active sender)
    receiver->SetReceiverName(name_utf8.get_data());

    _spout_receiver = receiver;
    _sender_name = name;
    _initialized = true;
    return true;
#else
    UtilityFunctions::push_warning("GNSpoutReceiver: Spout is only available on Windows.");
    return false;
#endif
}

PackedByteArray GNSpoutReceiver::receive_image() {
    PackedByteArray result;
#ifdef _WIN32
    if (!_initialized || _spout_receiver == nullptr) return result;

    auto *receiver = static_cast<SpoutReceiver *>(_spout_receiver);

    unsigned int w = 0, h = 0;

    // First call ReceiveImage with nullptr to connect/check for sender
    // then with a real buffer to get pixels. Or just allocate based on known size.
    // ReceiveImage handles connection internally — auto-connects on first call.

    // Pre-check: if we have known dimensions, allocate buffer
    w = receiver->GetSenderWidth();
    h = receiver->GetSenderHeight();

    if (w == 0 || h == 0) {
        // No sender connected yet — try to receive to trigger connection
        unsigned char dummy[4];
        receiver->ReceiveImage(dummy, GL_RGBA, false, 0);
        w = receiver->GetSenderWidth();
        h = receiver->GetSenderHeight();
        if (w == 0 || h == 0) return result;
    }

    _width = (int)w;
    _height = (int)h;

    int byte_count = _width * _height * 4;
    result.resize(byte_count);

    if (!receiver->ReceiveImage(result.ptrw(), GL_RGBA, false, 0)) {
        result.resize(0);
        return result;
    }

    const char *active_name = receiver->GetSenderName();
    if (active_name != nullptr) {
        _sender_name = String::utf8(active_name);
    }
#endif
    return result;
}

void GNSpoutReceiver::release_receiver() {
#ifdef _WIN32
    if (_spout_receiver != nullptr) {
        auto *receiver = static_cast<SpoutReceiver *>(_spout_receiver);
        receiver->ReleaseReceiver();
        delete receiver;
        _spout_receiver = nullptr;
    }
    _initialized = false;
    _width = 0;
    _height = 0;
#endif
}

bool GNSpoutReceiver::is_initialized() const {
#ifdef _WIN32
    return _initialized;
#else
    return false;
#endif
}

bool GNSpoutReceiver::is_updated() const {
#ifdef _WIN32
    if (!_initialized || _spout_receiver == nullptr) return false;
    auto *receiver = static_cast<SpoutReceiver *>(_spout_receiver);
    return receiver->IsUpdated();
#else
    return false;
#endif
}

String GNSpoutReceiver::get_sender_name() const {
#ifdef _WIN32
    return _sender_name;
#else
    return "";
#endif
}

int GNSpoutReceiver::get_width() const {
#ifdef _WIN32
    return _width;
#else
    return 0;
#endif
}

int GNSpoutReceiver::get_height() const {
#ifdef _WIN32
    return _height;
#else
    return 0;
#endif
}

PackedStringArray GNSpoutReceiver::get_sender_list() const {
    PackedStringArray list;
#ifdef _WIN32
    if (_spout_receiver == nullptr) return list;
    auto *receiver = static_cast<SpoutReceiver *>(_spout_receiver);
    std::vector<std::string> senders = receiver->GetSenderList();
    for (const auto &s : senders) {
        list.push_back(String::utf8(s.c_str()));
    }
#endif
    return list;
}

int GNSpoutReceiver::get_sender_count() const {
#ifdef _WIN32
    if (_spout_receiver == nullptr) return 0;
    auto *receiver = static_cast<SpoutReceiver *>(_spout_receiver);
    return (int)receiver->GetSenderList().size();
#else
    return 0;
#endif
}

} // namespace godot
