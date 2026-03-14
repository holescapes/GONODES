#include "gn_midi_in.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include "RtMidi.h"
#include <mutex>
#include <vector>

namespace godot {

struct MidiMessage {
    int status;
    int channel;
    int data1;
    int data2;
    double timestamp;
};

// RtMidi callback — called from the MIDI thread, pushes to queue
static void midi_callback(double timestamp, std::vector<unsigned char> *message, void *user_data) {
    if (!message || message->size() < 1) return;

    auto *pair = static_cast<std::pair<std::vector<MidiMessage> *, std::mutex *> *>(user_data);
    auto *queue = pair->first;
    auto *mtx = pair->second;

    MidiMessage msg;
    msg.timestamp = timestamp;
    msg.status = (*message)[0] & 0xF0;
    msg.channel = (*message)[0] & 0x0F;
    msg.data1 = message->size() > 1 ? (*message)[1] : 0;
    msg.data2 = message->size() > 2 ? (*message)[2] : 0;

    std::lock_guard<std::mutex> lock(*mtx);
    queue->push_back(msg);
}

void GNMidiIn::_bind_methods() {
    ClassDB::bind_method(D_METHOD("open_port", "port_index"), &GNMidiIn::open_port);
    ClassDB::bind_method(D_METHOD("open_virtual_port", "name"), &GNMidiIn::open_virtual_port);
    ClassDB::bind_method(D_METHOD("close_port"), &GNMidiIn::close_port);
    ClassDB::bind_method(D_METHOD("is_port_open"), &GNMidiIn::is_port_open);
    ClassDB::bind_method(D_METHOD("get_messages"), &GNMidiIn::get_messages);
    ClassDB::bind_method(D_METHOD("clear_messages"), &GNMidiIn::clear_messages);
    ClassDB::bind_static_method("GNMidiIn", D_METHOD("get_port_list"), &GNMidiIn::get_port_list);
    ClassDB::bind_static_method("GNMidiIn", D_METHOD("get_port_count"), &GNMidiIn::get_port_count);
}

GNMidiIn::GNMidiIn() {
    try {
        auto *midiin = new RtMidiIn();
        auto *queue = new std::vector<MidiMessage>();
        auto *mtx = new std::mutex();

        // Store callback user data as a pair (queue, mutex)
        auto *cb_data = new std::pair<std::vector<MidiMessage> *, std::mutex *>(queue, mtx);
        midiin->setCallback(midi_callback, cb_data);
        midiin->ignoreTypes(false, false, false); // Don't ignore sysex, timing, sensing

        _midi_in = midiin;
        _message_queue = queue;
        _mutex = mtx;
    } catch (...) {
        _midi_in = nullptr;
        _message_queue = nullptr;
        _mutex = nullptr;
    }
}

GNMidiIn::~GNMidiIn() {
    close_port();
    if (_midi_in) {
        auto *midiin = static_cast<RtMidiIn *>(_midi_in);
        // Clean up callback data
        midiin->cancelCallback();
        delete midiin;
    }
    if (_message_queue) delete static_cast<std::vector<MidiMessage> *>(_message_queue);
    if (_mutex) delete static_cast<std::mutex *>(_mutex);
}

bool GNMidiIn::open_port(int port_index) {
    if (!_midi_in) return false;
    close_port();

    auto *midiin = static_cast<RtMidiIn *>(_midi_in);
    try {
        if ((unsigned int)port_index >= midiin->getPortCount()) return false;
        midiin->openPort(port_index);
        _port_open = true;
        return true;
    } catch (...) {
        return false;
    }
}

bool GNMidiIn::open_virtual_port(const String &name) {
    if (!_midi_in) return false;
    close_port();

    auto *midiin = static_cast<RtMidiIn *>(_midi_in);
    try {
        CharString name_utf8 = name.utf8();
        midiin->openVirtualPort(name_utf8.get_data());
        _port_open = true;
        return true;
    } catch (...) {
        return false;
    }
}

void GNMidiIn::close_port() {
    if (_midi_in && _port_open) {
        auto *midiin = static_cast<RtMidiIn *>(_midi_in);
        midiin->closePort();
        _port_open = false;
    }
}

bool GNMidiIn::is_port_open() const {
    return _port_open;
}

Array GNMidiIn::get_messages() {
    Array result;
    if (!_message_queue || !_mutex) return result;

    auto *queue = static_cast<std::vector<MidiMessage> *>(_message_queue);
    auto *mtx = static_cast<std::mutex *>(_mutex);

    std::lock_guard<std::mutex> lock(*mtx);
    for (const auto &msg : *queue) {
        Dictionary d;
        d["status"] = msg.status;
        d["channel"] = msg.channel;
        d["data1"] = msg.data1;
        d["data2"] = msg.data2;
        d["timestamp"] = msg.timestamp;
        result.push_back(d);
    }
    queue->clear();
    return result;
}

void GNMidiIn::clear_messages() {
    if (!_message_queue || !_mutex) return;

    auto *queue = static_cast<std::vector<MidiMessage> *>(_message_queue);
    auto *mtx = static_cast<std::mutex *>(_mutex);

    std::lock_guard<std::mutex> lock(*mtx);
    queue->clear();
}

PackedStringArray GNMidiIn::get_port_list() {
    PackedStringArray list;
    try {
        RtMidiIn midiin;
        unsigned int count = midiin.getPortCount();
        for (unsigned int i = 0; i < count; i++) {
            list.push_back(String::utf8(midiin.getPortName(i).c_str()));
        }
    } catch (...) {}
    return list;
}

int GNMidiIn::get_port_count() {
    try {
        RtMidiIn midiin;
        return (int)midiin.getPortCount();
    } catch (...) {
        return 0;
    }
}

} // namespace godot
