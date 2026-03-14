#include "gn_midi_out.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include "RtMidi.h"
#include <vector>

namespace godot {

void GNMidiOut::_bind_methods() {
    ClassDB::bind_method(D_METHOD("open_port", "port_index"), &GNMidiOut::open_port);
    ClassDB::bind_method(D_METHOD("open_virtual_port", "name"), &GNMidiOut::open_virtual_port);
    ClassDB::bind_method(D_METHOD("close_port"), &GNMidiOut::close_port);
    ClassDB::bind_method(D_METHOD("is_port_open"), &GNMidiOut::is_port_open);
    ClassDB::bind_method(D_METHOD("send_note_on", "channel", "note", "velocity"), &GNMidiOut::send_note_on);
    ClassDB::bind_method(D_METHOD("send_note_off", "channel", "note", "velocity"), &GNMidiOut::send_note_off);
    ClassDB::bind_method(D_METHOD("send_cc", "channel", "cc_number", "value"), &GNMidiOut::send_cc);
    ClassDB::bind_method(D_METHOD("send_program_change", "channel", "program"), &GNMidiOut::send_program_change);
    ClassDB::bind_method(D_METHOD("send_pitch_bend", "channel", "value"), &GNMidiOut::send_pitch_bend);
    ClassDB::bind_method(D_METHOD("send_raw", "byte0", "byte1", "byte2"), &GNMidiOut::send_raw);
    ClassDB::bind_static_method("GNMidiOut", D_METHOD("get_port_list"), &GNMidiOut::get_port_list);
    ClassDB::bind_static_method("GNMidiOut", D_METHOD("get_port_count"), &GNMidiOut::get_port_count);
}

GNMidiOut::GNMidiOut() {
    try {
        _midi_out = new RtMidiOut();
    } catch (...) {
        _midi_out = nullptr;
    }
}

GNMidiOut::~GNMidiOut() {
    close_port();
    if (_midi_out) {
        delete static_cast<RtMidiOut *>(_midi_out);
    }
}

bool GNMidiOut::open_port(int port_index) {
    if (!_midi_out) return false;
    close_port();

    auto *midiout = static_cast<RtMidiOut *>(_midi_out);
    try {
        if ((unsigned int)port_index >= midiout->getPortCount()) return false;
        midiout->openPort(port_index);
        _port_open = true;
        return true;
    } catch (...) {
        return false;
    }
}

bool GNMidiOut::open_virtual_port(const String &name) {
    if (!_midi_out) return false;
    close_port();

    auto *midiout = static_cast<RtMidiOut *>(_midi_out);
    try {
        CharString name_utf8 = name.utf8();
        midiout->openVirtualPort(name_utf8.get_data());
        _port_open = true;
        return true;
    } catch (...) {
        return false;
    }
}

void GNMidiOut::close_port() {
    if (_midi_out && _port_open) {
        auto *midiout = static_cast<RtMidiOut *>(_midi_out);
        midiout->closePort();
        _port_open = false;
    }
}

bool GNMidiOut::is_port_open() const {
    return _port_open;
}

void GNMidiOut::send_note_on(int channel, int note, int velocity) {
    send_raw(0x90 | (channel & 0x0F), note & 0x7F, velocity & 0x7F);
}

void GNMidiOut::send_note_off(int channel, int note, int velocity) {
    send_raw(0x80 | (channel & 0x0F), note & 0x7F, velocity & 0x7F);
}

void GNMidiOut::send_cc(int channel, int cc_number, int value) {
    send_raw(0xB0 | (channel & 0x0F), cc_number & 0x7F, value & 0x7F);
}

void GNMidiOut::send_program_change(int channel, int program) {
    if (!_midi_out || !_port_open) return;
    auto *midiout = static_cast<RtMidiOut *>(_midi_out);
    try {
        std::vector<unsigned char> msg = {
            static_cast<unsigned char>(0xC0 | (channel & 0x0F)),
            static_cast<unsigned char>(program & 0x7F)
        };
        midiout->sendMessage(&msg);
    } catch (...) {}
}

void GNMidiOut::send_pitch_bend(int channel, int value) {
    // Pitch bend: 14-bit value (0-16383), center = 8192
    int clamped = value < 0 ? 0 : (value > 16383 ? 16383 : value);
    send_raw(0xE0 | (channel & 0x0F), clamped & 0x7F, (clamped >> 7) & 0x7F);
}

void GNMidiOut::send_raw(int byte0, int byte1, int byte2) {
    if (!_midi_out || !_port_open) return;
    auto *midiout = static_cast<RtMidiOut *>(_midi_out);
    try {
        std::vector<unsigned char> msg = {
            static_cast<unsigned char>(byte0 & 0xFF),
            static_cast<unsigned char>(byte1 & 0xFF),
            static_cast<unsigned char>(byte2 & 0xFF)
        };
        midiout->sendMessage(&msg);
    } catch (...) {}
}

PackedStringArray GNMidiOut::get_port_list() {
    PackedStringArray list;
    try {
        RtMidiOut midiout;
        unsigned int count = midiout.getPortCount();
        for (unsigned int i = 0; i < count; i++) {
            list.push_back(String::utf8(midiout.getPortName(i).c_str()));
        }
    } catch (...) {}
    return list;
}

int GNMidiOut::get_port_count() {
    try {
        RtMidiOut midiout;
        return (int)midiout.getPortCount();
    } catch (...) {
        return 0;
    }
}

} // namespace godot
