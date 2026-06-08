class_name SerialDAT
extends GNDatBase
## Serial port communication DAT (legacy placeholder).
##
## **DEPRECATED**: Use the gn_ext_serial extension instead, which provides
## dedicated SerialSendDAT and SerialReceiveDAT operators with proper
## scaffold-mode support and GDExtension backend detection.
##
## This node is kept for backward compatibility with existing patches.
## It forwards to SerialReceiveDAT behaviour when available.
##
## TouchDesigner equivalent: Serial DAT.

var _buffer: String = ""
var _rows: Array[PackedStringArray] = []
var _max_rows: int = 100


func _init() -> void:
	node_type = "serial"
	time_dependent = true
	deprecated = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, false, "Optional: data to send", "In")
	add_output("out", GNFamily.Type.DAT, "Received serial data", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("port", "COM3",
		"Port", "Serial port name (COM3, /dev/ttyUSB0, etc.)"))
	add_parameter(GNParameter.create_int("baud_rate", 9600, 300, 115200,
		"Baud Rate", "Communication speed"))
	add_parameter(GNParameter.create_enum("delimiter", ["Newline", "Null", "None"],
		0, "Delimiter", "Message delimiter"))
	add_parameter(GNParameter.create_int("max_rows", 100, 1, 10000,
		"Max Rows", "Maximum table rows to keep"))
	add_parameter(GNParameter.create_bool("active", false,
		"Active", "Enable serial communication"))
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

	var out := _prepare_table()
	out.set_headers(PackedStringArray(["timestamp", "message"]))

	# Output existing received data
	for row in _rows:
		out.append_row(row)

	if not active:
		if _rows.is_empty():
			out.append_row(PackedStringArray(["", "Serial inactive"]))
		return out

	# Note: actual serial I/O requires a native extension (GDNative/GDExtension)
	# with platform-specific serial port access.  This operator provides the
	# DAT framing and data flow — the low-level transport is pluggable.
	#
	# When a serial extension is available, it would:
	# 1. Open the port in _pre_cook() or on first cook
	# 2. Read available bytes into _buffer
	# 3. Split on delimiter and add to _rows
	# 4. Optionally send input DAT text
	#
	# For now, this acts as a placeholder that properly structures the data flow.

	return out


func _add_message(msg: String) -> void:
	var ts := "%.3f" % (Time.get_ticks_msec() / 1000.0)
	_rows.append(PackedStringArray([ts, msg]))
	while _rows.size() > _max_rows:
		_rows.remove_at(0)
