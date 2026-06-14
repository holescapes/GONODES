class_name SerialReceiveDAT
extends GNDatBase
## Serial port receiver DAT.
##
## Listens on a serial port and collects incoming data into a rolling
## DAT table.  Supports newline, null-terminated, or raw (no delimiter)
## framing.
##
## Uses the native GNNativeSerialPort C++ class (in gn_ext_native) for
## cross-platform serial I/O (Windows COM, Linux/macOS tty).  If the
## native extension is not loaded, the operator runs in scaffold mode.
##
## TouchDesigner equivalent: Serial DAT (receive side).

var _serial: RefCounted = null  # GNNativeSerialPort instance
var _has_native: bool = false
var _buffer: String = ""
var _rows: Array[PackedStringArray] = []
var _max_rows: int = 100
var _last_port: String = ""
var _last_baud: int = 0


func _init() -> void:
	node_type = "serial_receive"
	time_dependent = true
	thread_safe = false  # native serial port I/O
	node_description = "Serial port receiver. Collects incoming COM/tty data into a rolling table. Uses native C++ serial I/O when gn_ext_native is loaded."
	_has_native = ClassDB.class_exists(&"GNNativeSerialPort")


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "Received serial data")


func _init_parameters() -> void:
	var port_param := GNParameter.create_enum("port",
		PackedStringArray(["COM3"]), 0, "Port",
		"Serial port. Populated from available ports when native extension is loaded.")
	port_param.dynamic_enum_callback = Callable(self, "_get_port_menu")
	add_parameter(port_param)
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

	if _serial == null or not _serial.is_open():
		_open_port()
	if _serial == null:
		return

	# Read available data
	var available: int = _serial.get_available()
	if available <= 0:
		return

	var raw: PackedByteArray = _serial.read_data(available)
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
func _get_port_menu() -> PackedStringArray:
	if ClassDB.class_exists(&"GNNativeSerialPort"):
		var ports: PackedStringArray = ClassDB.class_call_static(&"GNNativeSerialPort", &"list_ports")
		if not ports.is_empty():
			return ports
	return PackedStringArray(["COM3"])


func _get_selected_port_name() -> String:
	var idx: int = get_param_value("port")
	var ports := _get_port_menu()
	if idx < ports.size():
		return ports[idx]
	return ""


func _open_port() -> void:
	if not _has_native:
		return
	var port_name: String = _get_selected_port_name()
	var baud: int = get_param_value("baud_rate")
	# Reopen if port/baud changed
	if _serial != null and _serial.is_open():
		if port_name == _last_port and baud == _last_baud:
			return
		_serial.close_port()
	_serial = ClassDB.instantiate(&"GNNativeSerialPort")
	var err: int = _serial.open_port(port_name, baud)
	if err != OK:
		push_warning("SerialReceiveDAT: Could not open %s at %d baud" % [port_name, baud])
		_serial = null
	else:
		_last_port = port_name
		_last_baud = baud


func _close_port() -> void:
	if _serial != null:
		_serial.close_port()
		_serial = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_close_port()


func _on_parameter_changed(param_name: String, _new_value: Variant) -> void:
	if param_name == "port" or param_name == "baud_rate":
		# Clear cache so _open_port() reconnects on next cook.
		_last_port = ""
		_last_baud = 0
