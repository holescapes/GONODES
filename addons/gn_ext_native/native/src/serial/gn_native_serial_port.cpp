#include "gn_native_serial_port.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#ifdef _WIN32
// Windows includes already in header
#else
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <errno.h>
#include <dirent.h>
#include <cstring>
#endif

namespace godot {

// ═══════════════════════════════════════════════════════════════════════════════
// Binding
// ═══════════════════════════════════════════════════════════════════════════════

void GNNativeSerialPort::_bind_methods() {
    ClassDB::bind_method(D_METHOD("open_port", "port_name", "baud_rate"),
                         &GNNativeSerialPort::open_port);
    ClassDB::bind_method(D_METHOD("close_port"),
                         &GNNativeSerialPort::close_port);
    ClassDB::bind_method(D_METHOD("is_open"),
                         &GNNativeSerialPort::is_open);
    ClassDB::bind_method(D_METHOD("write_data", "data"),
                         &GNNativeSerialPort::write_data);
    ClassDB::bind_method(D_METHOD("get_available"),
                         &GNNativeSerialPort::get_available);
    ClassDB::bind_method(D_METHOD("read_data", "max_bytes"),
                         &GNNativeSerialPort::read_data);
    ClassDB::bind_method(D_METHOD("get_port_name"),
                         &GNNativeSerialPort::get_port_name);
    ClassDB::bind_method(D_METHOD("get_baud_rate"),
                         &GNNativeSerialPort::get_baud_rate);
    ClassDB::bind_static_method("GNNativeSerialPort",
                                D_METHOD("list_ports"),
                                &GNNativeSerialPort::list_ports);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Lifecycle
// ═══════════════════════════════════════════════════════════════════════════════

GNNativeSerialPort::GNNativeSerialPort() {}

GNNativeSerialPort::~GNNativeSerialPort() {
    close_port();
}

// ═══════════════════════════════════════════════════════════════════════════════
// Public API
// ═══════════════════════════════════════════════════════════════════════════════

String GNNativeSerialPort::get_port_name() const { return _port_name; }
int GNNativeSerialPort::get_baud_rate() const { return _baud_rate; }

bool GNNativeSerialPort::is_open() const {
    std::lock_guard<std::mutex> lock(_mutex);
    return _is_open;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Windows Implementation
// ═══════════════════════════════════════════════════════════════════════════════

#ifdef _WIN32

int GNNativeSerialPort::open_port(const String &port_name, int baud_rate) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (_is_open) {
        close_port();
    }

    _port_name = port_name;
    _baud_rate = baud_rate;

    // Windows COM ports above 9 need the \\.\COMn prefix
    String win_path = port_name;
    if (port_name.begins_with("COM") && !port_name.begins_with("\\\\.\\")) {
        win_path = "\\\\.\\" + port_name;
    }

    _handle = CreateFileW(
        (LPCWSTR)win_path.utf16().ptr(),
        GENERIC_READ | GENERIC_WRITE,
        0,            // no sharing
        nullptr,      // default security
        OPEN_EXISTING,
        0,            // synchronous I/O
        nullptr);

    if (_handle == INVALID_HANDLE_VALUE) {
        UtilityFunctions::push_warning(
            String("GNNativeSerialPort: Failed to open ") + port_name);
        return 12; // ERR_CANT_OPEN
    }

    if (!_configure_win(baud_rate)) {
        CloseHandle(_handle);
        _handle = INVALID_HANDLE_VALUE;
        return 12;
    }

    _is_open = true;
    return 0; // OK
}

void GNNativeSerialPort::close_port() {
    // Note: caller may or may not hold mutex
    if (_handle != INVALID_HANDLE_VALUE) {
        CloseHandle(_handle);
        _handle = INVALID_HANDLE_VALUE;
    }
    _is_open = false;
}

int GNNativeSerialPort::write_data(const PackedByteArray &data) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (!_is_open) return 0;

    DWORD written = 0;
    WriteFile(_handle, data.ptr(), (DWORD)data.size(), &written, nullptr);
    return (int)written;
}

int GNNativeSerialPort::get_available() const {
    std::lock_guard<std::mutex> lock(_mutex);
    if (!_is_open) return 0;

    DWORD errors;
    COMSTAT stat;
    if (ClearCommError(_handle, &errors, &stat)) {
        return (int)stat.cbInQue;
    }
    return 0;
}

PackedByteArray GNNativeSerialPort::read_data(int max_bytes) {
    std::lock_guard<std::mutex> lock(_mutex);
    PackedByteArray result;
    if (!_is_open || max_bytes <= 0) return result;

    result.resize(max_bytes);
    DWORD bytes_read = 0;
    ReadFile(_handle, result.ptrw(), (DWORD)max_bytes, &bytes_read, nullptr);
    result.resize((int)bytes_read);
    return result;
}

bool GNNativeSerialPort::_configure_win(int baud) {
    DCB dcb;
    memset(&dcb, 0, sizeof(dcb));
    dcb.DCBlength = sizeof(dcb);

    if (!GetCommState(_handle, &dcb)) return false;

    dcb.BaudRate = (DWORD)baud;
    dcb.ByteSize = 8;
    dcb.StopBits = ONESTOPBIT;
    dcb.Parity   = NOPARITY;
    dcb.fBinary  = TRUE;
    dcb.fDtrControl = DTR_CONTROL_ENABLE;
    dcb.fRtsControl = RTS_CONTROL_ENABLE;
    dcb.fOutxCtsFlow = FALSE;
    dcb.fOutxDsrFlow = FALSE;
    dcb.fDsrSensitivity = FALSE;
    dcb.fOutX = FALSE;
    dcb.fInX = FALSE;

    if (!SetCommState(_handle, &dcb)) return false;

    // Timeouts: non-blocking reads (return immediately with available data)
    COMMTIMEOUTS timeouts;
    timeouts.ReadIntervalTimeout         = MAXDWORD;
    timeouts.ReadTotalTimeoutMultiplier  = 0;
    timeouts.ReadTotalTimeoutConstant    = 0;
    timeouts.WriteTotalTimeoutMultiplier = 0;
    timeouts.WriteTotalTimeoutConstant   = 100; // 100ms write timeout
    SetCommTimeouts(_handle, &timeouts);

    PurgeComm(_handle, PURGE_RXCLEAR | PURGE_TXCLEAR);
    return true;
}

PackedStringArray GNNativeSerialPort::list_ports() {
    PackedStringArray ports;
    // Enumerate COM1..COM256
    for (int i = 1; i <= 256; ++i) {
        String name = "COM" + String::num_int64(i);
        String path = "\\\\.\\" + name;
        HANDLE h = CreateFileW(
            (LPCWSTR)path.utf16().ptr(),
            GENERIC_READ | GENERIC_WRITE,
            0, nullptr, OPEN_EXISTING, 0, nullptr);
        if (h != INVALID_HANDLE_VALUE) {
            CloseHandle(h);
            ports.append(name);
        }
    }
    return ports;
}

// ═══════════════════════════════════════════════════════════════════════════════
// POSIX Implementation (Linux / macOS)
// ═══════════════════════════════════════════════════════════════════════════════

#else

int GNNativeSerialPort::open_port(const String &port_name, int baud_rate) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (_is_open) {
        close_port();
    }

    _port_name = port_name;
    _baud_rate = baud_rate;

    _fd = ::open(port_name.utf8().get_data(), O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (_fd < 0) {
        UtilityFunctions::push_warning(
            String("GNNativeSerialPort: Failed to open ") + port_name +
            String(" (errno ") + String::num_int64(errno) + String(")"));
        return 12; // ERR_CANT_OPEN
    }

    if (!_configure_posix(baud_rate)) {
        ::close(_fd);
        _fd = -1;
        return 12;
    }

    _is_open = true;
    return 0; // OK
}

void GNNativeSerialPort::close_port() {
    if (_fd >= 0) {
        // Restore original terminal settings
        tcsetattr(_fd, TCSANOW, &_orig_termios);
        ::close(_fd);
        _fd = -1;
    }
    _is_open = false;
}

int GNNativeSerialPort::write_data(const PackedByteArray &data) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (!_is_open) return 0;

    ssize_t written = ::write(_fd, data.ptr(), data.size());
    return written > 0 ? (int)written : 0;
}

int GNNativeSerialPort::get_available() const {
    std::lock_guard<std::mutex> lock(_mutex);
    if (!_is_open) return 0;

    int bytes_available = 0;
    if (ioctl(_fd, FIONREAD, &bytes_available) < 0) {
        return 0;
    }
    return bytes_available;
}

PackedByteArray GNNativeSerialPort::read_data(int max_bytes) {
    std::lock_guard<std::mutex> lock(_mutex);
    PackedByteArray result;
    if (!_is_open || max_bytes <= 0) return result;

    result.resize(max_bytes);
    ssize_t bytes_read = ::read(_fd, result.ptrw(), max_bytes);
    if (bytes_read < 0) {
        // EAGAIN/EWOULDBLOCK means no data (non-blocking)
        result.resize(0);
    } else {
        result.resize((int)bytes_read);
    }
    return result;
}

speed_t GNNativeSerialPort::_baud_constant(int baud) {
    switch (baud) {
        case 300:    return B300;
        case 600:    return B600;
        case 1200:   return B1200;
        case 2400:   return B2400;
        case 4800:   return B4800;
        case 9600:   return B9600;
        case 19200:  return B19200;
        case 38400:  return B38400;
        case 57600:  return B57600;
        case 115200: return B115200;
#ifdef B230400
        case 230400: return B230400;
#endif
#ifdef B460800
        case 460800: return B460800;
#endif
#ifdef B921600
        case 921600: return B921600;
#endif
        default:     return B9600;
    }
}

bool GNNativeSerialPort::_configure_posix(int baud) {
    if (tcgetattr(_fd, &_orig_termios) < 0) return false;

    struct termios tio;
    memset(&tio, 0, sizeof(tio));

    speed_t speed = _baud_constant(baud);
    cfsetispeed(&tio, speed);
    cfsetospeed(&tio, speed);

    // Raw mode: 8N1, no flow control
    tio.c_cflag |= (CS8 | CLOCAL | CREAD);
    tio.c_iflag = 0;
    tio.c_oflag = 0;
    tio.c_lflag = 0;

    // Non-blocking read: return immediately with whatever is available
    tio.c_cc[VMIN]  = 0;
    tio.c_cc[VTIME] = 0;

    tcflush(_fd, TCIOFLUSH);
    return tcsetattr(_fd, TCSANOW, &tio) == 0;
}

PackedStringArray GNNativeSerialPort::list_ports() {
    PackedStringArray ports;

#ifdef __APPLE__
    // macOS: /dev/cu.* and /dev/tty.*
    DIR *dir = opendir("/dev");
    if (dir) {
        struct dirent *entry;
        while ((entry = readdir(dir)) != nullptr) {
            String name(entry->d_name);
            if (name.begins_with("cu.") || name.begins_with("tty.usb") ||
                name.begins_with("tty.serial")) {
                ports.append(String("/dev/") + name);
            }
        }
        closedir(dir);
    }
#else
    // Linux: /dev/ttyUSB*, /dev/ttyACM*, /dev/ttyS*
    DIR *dir = opendir("/dev");
    if (dir) {
        struct dirent *entry;
        while ((entry = readdir(dir)) != nullptr) {
            String name(entry->d_name);
            if (name.begins_with("ttyUSB") || name.begins_with("ttyACM") ||
                name.begins_with("ttyS")) {
                ports.append(String("/dev/") + name);
            }
        }
        closedir(dir);
    }
#endif

    return ports;
}

#endif // _WIN32 / POSIX

} // namespace godot
