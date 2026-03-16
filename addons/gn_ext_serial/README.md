# Serial Port Extension for GONODES

Provides bidirectional serial port (COM / tty) communication via two DAT operators:

| Operator | Direction | Description |
|----------|-----------|-------------|
| **SerialSendDAT** | Out | Sends DAT rows or CHOP values as serial messages |
| **SerialReceiveDAT** | In | Receives serial data into a rolling DAT table |

## Requirements

Actual hardware I/O requires a **GDExtension** that exposes a `SerialPort` class with at minimum:

```
SerialPort.open(port_name: String, baud_rate: int) -> Error
SerialPort.write(data: PackedByteArray) -> void
SerialPort.read(bytes: int) -> PackedByteArray
SerialPort.get_available() -> int
SerialPort.close() -> void
```

Without the native backend, both operators run in **scaffold mode** — data flow and table structure work correctly, but no bytes are sent or received on the wire.

### Recommended GDExtensions

- [gdserialport](https://github.com/matrixant/serial_port) — Cross-platform serial port for Godot 4.x
- Custom C++ GDExtension wrapping your platform's serial API

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
