class_name SerialSendDAT
extends GNDatBase
## Serial port sender DAT.
##
## Sends text or binary data to a serial port.  Accepts an optional DAT
## input (each row is sent as a message) or CHOP input (channel values
## formatted per *format* parameter).
##
## **Requires a serial GDExtension** (e.g. GDSerialPort) that exposes
## `SerialPort.open()`, `.write()`, `.close()`.  Without it the operator
## runs in scaffold mode — it formats and queues messages but does not
## perform actual hardware I/O.
##
## TouchDesigner equivalent: Serial DAT (send side).

# ── Native backend ─────────────────────────────────────────────────────────────
# When a GDExtension named "SerialPort" is available, it will be detected
# automatically.  Set _serial to the opened port instance.
var _serial: RefCounted = null  # SerialPort instance (when extension loaded)
var _has_native: bool = false
var _send_log: Array[PackedStringArray] = []
var _max_log: int = 50
var _last_port: String = ""
var _last_baud: int = 0


func _init() -> void:
	node_type = "serial_send"
	time_dependent = true
	thread_safe = false  # native serial port I/O
	node_description = "Serial port sender. Transmits DAT rows or CHOP values over a COM/tty port. Uses native C++ serial I/O when gn_ext_native is loaded."
	_has_native = ClassDB.class_exists(&"GNNativeSerialPort")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, false, "Text messages to send (one per row)")
	add_output("out", GNFamily.Type.DAT, "Send log")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("port", "COM3",
		"Port", "Serial port name (COM3, /dev/ttyUSB0, etc.)"))
	add_parameter(GNParameter.create_int("baud_rate", 9600, 300, 115200,
		"Baud Rate", "Communication speed"))
	add_parameter(GNParameter.create_enum("line_ending", ["None", "LF", "CR", "CRLF"], 1,
		"Line Ending", "Appended to each sent message"))
	add_parameter(GNParameter.create_bool("active", false,
		"Active", "Enable serial transmission"))
	add_parameter(GNParameter.create_pulse("send_now",
		"Send Now", "Immediately send the current input"))
	add_parameter(GNParameter.create_bool("continuous", false,
		"Continuous", "Send every cook (not just on pulse)"))
	add_parameter(GNParameter.create_pulse("clear_log",
		"Clear Log", "Clear the send log"))


func _cook(inputs: Array[GNData]) -> GNData:
	var active: bool = get_param_value("active")
	var send_pulse: bool = get_param_value("send_now")
	var continuous: bool = get_param_value("continuous")
	var clear: bool = get_param_value("clear_log")

	if clear:
		_send_log.clear()
		if parameters.has("clear_log"):
			parameters["clear_log"].value = false

	if send_pulse and parameters.has("send_now"):
		parameters["send_now"].value = false

	var should_send := active and (continuous or send_pulse)

	if should_send:
		var messages := _collect_messages(inputs)
		for msg in messages:
			_transmit(msg)

	# Build output log table
	var out := _prepare_table()
	out.set_headers(PackedStringArray(["timestamp", "message", "status"]))
	for row in _send_log:
		out.append_row(row)
	if _send_log.is_empty():
		var status := "no extension" if not _has_native else ("inactive" if not active else "idle")
		out.append_row(PackedStringArray(["", "", status]))
	return out


## Collects messages from the input DAT (or fallback empty).
func _collect_messages(inputs: Array[GNData]) -> PackedStringArray:
	var messages := PackedStringArray()
	var in_dat := _get_input_dat(inputs, 0)
	if in_dat != null:
		for i in range(in_dat.get_row_count()):
			var row := in_dat.get_row(i)
			if row.size() > 0:
				messages.append("\t".join(row))
	return messages


## Transmits a single message. Uses native extension if available,
## otherwise logs in scaffold mode.
func _transmit(msg: String) -> void:
	var line_ending := _get_line_ending()
	var full_msg := msg + line_ending
	var ts := "%.3f" % (Time.get_ticks_msec() / 1000.0)

	if _has_native and _serial != null and _serial.is_open():
		_serial.write_data(full_msg.to_utf8_buffer())
		_log_entry(ts, msg, "sent")
	elif _has_native:
		_open_port()
		if _serial != null and _serial.is_open():
			_serial.write_data(full_msg.to_utf8_buffer())
			_log_entry(ts, msg, "sent")
		else:
			_log_entry(ts, msg, "error: port not opened")
	else:
		# Scaffold mode — no native extension
		_log_entry(ts, msg, "scaffold (no serial extension)")


func _log_entry(ts: String, msg: String, status: String) -> void:
	_send_log.append(PackedStringArray([ts, msg, status]))
	while _send_log.size() > _max_log:
		_send_log.remove_at(0)


func _get_line_ending() -> String:
	var idx: int = get_param_value("line_ending")
	match idx:
		0: return ""
		1: return "\n"
		2: return "\r"
		3: return "\r\n"
	return "\n"


## Attempts to open the serial port via native extension.
func _open_port() -> void:
	if not _has_native:
		return
	var port_name: String = get_param_value("port")
	var baud: int = get_param_value("baud_rate")
	# Reopen if port/baud changed
	if _serial != null and _serial.is_open():
		if port_name == _last_port and baud == _last_baud:
			return
		_serial.close_port()
	_serial = ClassDB.instantiate(&"GNNativeSerialPort")
	var err: int = _serial.open_port(port_name, baud)
	if err != OK:
		push_warning("SerialSendDAT: Could not open %s at %d baud" % [port_name, baud])
		_serial = null
	else:
		_last_port = port_name
		_last_baud = baud


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _serial != null:
			_serial.close_port()
			_serial = null
