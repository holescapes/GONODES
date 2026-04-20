# Serial Port Extension for GONODES

Provides bidirectional serial port (COM / tty) communication via two DAT operators:

| Operator | Direction | Description |
|----------|-----------|-------------|
| **SerialSendDAT** | Out | Sends DAT rows as serial messages |
| **SerialReceiveDAT** | In | Receives serial data into a rolling DAT table |

## Native Backend

Serial I/O is handled by the **GNNativeSerialPort** C++ class, built as part
of the `gn_ext_native` GDExtension. This provides cross-platform hardware
access:

| Platform | Backend | Port format |
|----------|---------|-------------|
| **Windows** | `CreateFileW` / `ReadFile` / `WriteFile` (Win32 API) | `COM3`, `COM10`, etc. |
| **Linux** | POSIX `open()` / `read()` / `write()` + `termios` | `/dev/ttyUSB0`, `/dev/ttyACM0` |
| **macOS** | Same POSIX backend | `/dev/cu.usbserial-*`, `/dev/tty.usbmodem-*` |

The C++ source is at `addons/gn_ext_native/native/src/serial/gn_native_serial_port.cpp`.

### Scaffold Mode

If `gn_ext_native` is not loaded (e.g., web builds or missing DLL), both
operators run in **scaffold mode** — data flow and table structure work
correctly, but no bytes are sent or received on the wire.  The output
table shows a `"no extension"` status.

## Building

Serial support is part of the main `gn_ext_native` build:

```bash
cd addons/gn_ext_native/native
scons platform=windows target=template_release
```

No additional dependencies — serial APIs are provided by the OS.

## Parameters

### SerialSendDAT

| Parameter | Default | Description |
|-----------|---------|-------------|
| Port | COM3 | Serial port name |
| Baud Rate | 9600 | Communication speed (300–115200) |
| Line Ending | LF | Appended to each message (None/LF/CR/CRLF) |
| Active | off | Enable serial transmission |
| Continuous | off | Send every cook (vs. pulse-triggered) |
| Send Now | pulse | Immediately send current input |
| Clear Log | pulse | Clear the send log |

### SerialReceiveDAT

| Parameter | Default | Description |
|-----------|---------|-------------|
| Port | COM3 | Serial port name |
| Baud Rate | 9600 | Communication speed (300–115200) |
| Delimiter | Newline | Message framing (Newline/Null/None) |
| Max Rows | 100 | Rolling buffer size |
| Active | off | Enable serial listening |
| Clear | pulse | Clear receive buffer |
