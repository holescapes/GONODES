class_name SerialReceiveDAT
extends GNDatBase
## Serial port receiver DAT.
##
## Listens on a serial port and collects incoming data into a rolling
## DAT table.  Supports newline, null-terminated, or raw (no delimiter)
## framing.
##
## **Requires a serial GDExtension** (e.g. GDSerialPort) that exposes
## `SerialPort.open()`, `.read()` / `.get_available()`, `.close()`.
## Without it the operator runs in scaffold mode — the table structure
## is correct but no hardware I/O occurs.
##
## TouchDesigner equivalent: Serial DAT (receive side).

var _serial: RefCounted = null  # SerialPort instance (when extension loaded)
var _has_native: bool = false
var _buffer: String = ""
var _rows: Array[PackedStringArray] = []
var _max_rows: int = 100


func _init() -> void:
	node_type = "serial_receive"
	time_dependent = true
	node_description = "Serial port receiver. Collects incoming COM/tty data into a rolling table. Requires a serial GDExtension for actual hardware I/O."
	_has_native = ClassDB.class_exists(&"SerialPort")


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "Received serial data")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("port", "COM3",
		"Port", "Serial port name (COM3, /dev/ttyUSB0, etc.)"))
	add_parameter(GNParameter.create_int("baud_rate", 9600, 300, 115200,
		"Baud Rate", "Communication speed"))
	add_parameter(GNParameter.create_enum("delimiter", ["Newline", "Null", "None"], 0,
		"Delimiter", "Message delimiter for framing"))
	add_parameter(GNParameter.create_int("max_rows", 100, 1, 10000,
		"Max Rows", "Maximum table rows to keep"))
	add_parameter(GNParameter.create_bool("active", false,
		"Active", "Enable serial listening"))
	add_parameter(GNParameter.create_pulse("clear",
		"Clear", "Clear received data buffer"))


func _cook(inputs: Array[GNData]) -> GNData:
	var active: bool = get_param_value("active")
	var clear_pulse: bool = get_param_value("clear")
	_max_rows = get_param_value("max_rows")

	if clear_pulse:
		_rows.clear()
		_buffer = ""
		if parameters.has("clear"):
			parameters["clear"].value = false

	if active:
		_poll_serial()
	else:
		_close_port()

	# Build output table
	var out := _prepare_table()
	out.set_headers(PackedStringArray(["timestamp", "message"]))
	for row in _rows:
		out.append_row(row)
	if _rows.is_empty():
		var status := "no extension" if not _has_native else ("inactive" if not active else "listening")
		out.append_row(PackedStringArray(["", status]))
	return out


## Reads available bytes from the serial port and frames into messages.
func _poll_serial() -> void:
	if not _has_native:
		return

	if _serial == null:
		_open_port()
	if _serial == null:
		return

	# Read available data
	var available: int = _serial.call("get_available")
	if available <= 0:
		return

	var raw: PackedByteArray = _serial.call("read", available)
	if raw.is_empty():
		return

	var text := raw.get_string_from_utf8()
	_buffer += text

	# Frame messages based on delimiter
	var delim_idx: int = get_param_value("delimiter")
	match delim_idx:
		0:  # Newline
			_split_buffer("\n")
		1:  # Null
			_split_buffer(String.chr(0))
		2:  # None — each poll is one message
			_add_message(_buffer)
			_buffer = ""


## Splits the buffer on a delimiter, adding complete messages.
func _split_buffer(delim: String) -> void:
	while true:
		var pos := _buffer.find(delim)
		if pos < 0:
			break
		var msg := _buffer.substr(0, pos).strip_edges()
		if not msg.is_empty():
			_add_message(msg)
		_buffer = _buffer.substr(pos + delim.length())


## Adds a timestamped message to the rolling buffer.
func _add_message(msg: String) -> void:
	var ts := "%.3f" % (Time.get_ticks_msec() / 1000.0)
	_rows.append(PackedStringArray([ts, msg]))
	while _rows.size() > _max_rows:
		_rows.remove_at(0)


## Opens the serial port via native extension.
func _open_port() -> void:
	if not _has_native:
		return
	var port_name: String = get_param_value("port")
	var baud: int = get_param_value("baud_rate")
	_serial = ClassDB.instantiate(&"SerialPort")
	if _serial == null:
		return
	var err = _serial.call("open", port_name, baud)
	if err != OK:
		push_warning("SerialReceiveDAT: Could not open %s at %d baud" % [port_name, baud])
		_serial = null


## Closes the serial port.
func _close_port() -> void:
	if _serial != null:
		_serial.call("close")
		_serial = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_close_port()
