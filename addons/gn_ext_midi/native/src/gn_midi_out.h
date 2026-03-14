#ifndef GN_MIDI_OUT_H
#define GN_MIDI_OUT_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

/// Wraps RtMidiOut for sending MIDI messages to external devices.
class GNMidiOut : public RefCounted {
    GDCLASS(GNMidiOut, RefCounted)

protected:
    static void _bind_methods();

public:
    GNMidiOut();
    ~GNMidiOut();

    bool open_port(int port_index);
    bool open_virtual_port(const String &name);
    void close_port();
    bool is_port_open() const;

    void send_note_on(int channel, int note, int velocity);
    void send_note_off(int channel, int note, int velocity);
    void send_cc(int channel, int cc_number, int value);
    void send_program_change(int channel, int program);
    void send_pitch_bend(int channel, int value);
    void send_raw(int byte0, int byte1, int byte2);

    static PackedStringArray get_port_list();
    static int get_port_count();

private:
    void *_midi_out = nullptr; // RtMidiOut*
    bool _port_open = false;
};

} // namespace godot

#endif // GN_MIDI_OUT_H
