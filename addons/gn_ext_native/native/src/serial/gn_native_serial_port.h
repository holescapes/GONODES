#ifndef GN_NATIVE_SERIAL_PORT_H
#define GN_NATIVE_SERIAL_PORT_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <mutex>

#ifdef _WIN32
#include <windows.h>
#else
#include <termios.h>
#endif

namespace godot {

/// Cross-platform serial port I/O for GONODES.
///
/// Windows: CreateFileW / ReadFile / WriteFile
/// Linux/macOS: open() / read() / write() + termios
///
/// Used by the SerialSendDAT and SerialReceiveDAT GDScript operators.
class GNNativeSerialPort : public RefCounted {
    GDCLASS(GNNativeSerialPort, RefCounted)

protected:
    static void _bind_methods();

public:
    GNNativeSerialPort();
    ~GNNativeSerialPort();

    /// Opens the serial port. Returns OK on success, ERR_CANT_OPEN on failure.
    int open_port(const String &port_name, int baud_rate);

    /// Closes the serial port.
    void close_port();

    /// Returns true if the port is currently open.
    bool is_open() const;

    /// Writes data to the serial port. Returns bytes written.
    int write_data(const PackedByteArray &data);

    /// Returns the number of bytes available to read.
    int get_available() const;

    /// Reads up to max_bytes from the serial port.
    PackedByteArray read_data(int max_bytes);

    /// Lists available serial port names on the system.
    static PackedStringArray list_ports();

    /// Gets the current port name.
    String get_port_name() const;

    /// Gets the current baud rate.
    int get_baud_rate() const;

private:
    String _port_name;
    int _baud_rate = 9600;
    bool _is_open = false;
    mutable std::mutex _mutex;

#ifdef _WIN32
    HANDLE _handle = INVALID_HANDLE_VALUE;
    bool _configure_win(int baud);
#else
    int _fd = -1;
    struct termios _orig_termios;
    bool _configure_posix(int baud);
    static speed_t _baud_constant(int baud);
#endif
};

} // namespace godot

#endif // GN_NATIVE_SERIAL_PORT_H
