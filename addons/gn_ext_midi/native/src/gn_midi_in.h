#ifndef GN_MIDI_IN_H
#define GN_MIDI_IN_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

/// Wraps RtMidiIn for receiving MIDI messages from external devices.
/// Messages are queued and retrieved via get_messages().
class GNMidiIn : public RefCounted {
    GDCLASS(GNMidiIn, RefCounted)

protected:
    static void _bind_methods();

public:
    GNMidiIn();
    ~GNMidiIn();

    bool open_port(int port_index);
    bool open_virtual_port(const String &name);
    void close_port();
    bool is_port_open() const;

    /// Returns queued messages as Array of Dictionary:
    /// { "status": int, "channel": int, "data1": int, "data2": int, "timestamp": float }
    Array get_messages();

    /// Clears the internal message queue.
    void clear_messages();

    static PackedStringArray get_port_list();
    static int get_port_count();

private:
    void *_midi_in = nullptr; // RtMidiIn*
    void *_message_queue = nullptr; // std::vector<MidiMessage>*
    void *_mutex = nullptr; // std::mutex*
    bool _port_open = false;
};

} // namespace godot

#endif // GN_MIDI_IN_H
