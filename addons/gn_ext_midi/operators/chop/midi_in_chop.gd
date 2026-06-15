class_name RtMidiInCHOP
extends GNChopBase
## Receive MIDI messages via RtMidi native library.
## Lower latency than Godot's built-in MIDI.
## Outputs channel data: note velocity (n0-n127), CC values (cc0-cc127),
## pitch bend, and raw message fields.

var _midi_in: RefCounted = null
var _port_open := false
var _prev_port := -1
var _devices_initialized: bool = false

# State tracking for note velocities and CC values
var _note_velocities: PackedFloat32Array = PackedFloat32Array()
var _cc_values: PackedFloat32Array = PackedFloat32Array()
var _pitch_bend: float = 0.0


func _init() -> void:
	node_type = "rtmidiin"
	time_dependent = true
	thread_safe = false  # native GNMidiIn I/O
	node_description = "Receive MIDI via RtMidi native library."
	if ClassDB.class_exists("GNMidiIn"):
		_midi_in = ClassDB.instantiate("GNMidiIn")
	_note_velocities.resize(128)
	_note_velocities.fill(0.0)
	_cc_values.resize(128)
	_cc_values.fill(0.0)


## MIDI hardware not available on web.
func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux", "android", "ios"])


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "MIDI channel data")


func _init_parameters() -> void:
	var port_param := GNParameter.create_enum("port",
		PackedStringArray(["Port 0"]), 0, "Port",
		"MIDI input port. Populated from connected devices via RtMidi.")
	port_param.dynamic_enum_callback = Callable(self, "_get_port_menu")
	add_parameter(port_param)
	add_parameter(GNParameter.create_int("channel_filter", -1, -1, 15, "Channel Filter",
		"MIDI channel to listen to (-1 = all channels)."))
	add_parameter(GNParameter.create_bool("notes", true, "Output Notes",
		"Output note velocity channels (n0-n127)."))
	add_parameter(GNParameter.create_bool("ccs", true, "Output CCs",
		"Output CC value channels (cc0-cc127)."))
	add_parameter(GNParameter.create_bool("normalize", true, "Normalize",
		"Output values 0.0-1.0 instead of 0-127."))


func _cook(_inputs: Array[GNData]) -> GNData:
	if not _devices_initialized:
		refresh_dynamic_enums()
		_devices_initialized = true
	if _midi_in == null:
		node_warning = "Native MIDI requires the gn_ext_midi library."
		return null

	var port: int = get_param_value("port")
	var ch_filter: int = get_param_value("channel_filter")
	var output_notes: bool = get_param_value("notes")
	var output_ccs: bool = get_param_value("ccs")
	var normalize: bool = get_param_value("normalize")

	# (Re)open port if changed
	if port != _prev_port:
		_midi_in.close_port()
		_port_open = false
		if not _midi_in.open_port(port):
			node_warning = "Failed to open native MIDI input port %d." % port
			return null
		_port_open = true
		_prev_port = port

	if not _port_open:
		return null

	# Process queued messages
	var messages: Array = _midi_in.get_messages()
	for msg in messages:
		var status: int = msg["status"]
		var channel: int = msg["channel"]
		var d1: int = msg["data1"]
		var d2: int = msg["data2"]

		# Filter by channel if set
		if ch_filter >= 0 and channel != ch_filter:
			continue

		if status == 0x90: # Note On
			_note_velocities[d1] = float(d2)
		elif status == 0x80: # Note Off
			_note_velocities[d1] = 0.0
		elif status == 0xB0: # CC
			_cc_values[d1] = float(d2)
		elif status == 0xE0: # Pitch Bend
			_pitch_bend = float(d1 | (d2 << 7))

	# Build output channels
	var out := _prepare_output()
	var div: float = 127.0 if normalize else 1.0

	if output_notes:
		for i in 128:
			if _note_velocities[i] > 0.0:
				out.set_single_value("n%d" % i, _note_velocities[i] / div)

	if output_ccs:
		for i in 128:
			if _cc_values[i] > 0.0:
				out.set_single_value("cc%d" % i, _cc_values[i] / div)

	# Always output pitch bend (normalized to -1..1 or raw 0..16383)
	if normalize:
		out.set_single_value("pitch_bend", (_pitch_bend - 8192.0) / 8192.0)
	else:
		out.set_single_value("pitch_bend", _pitch_bend)

	return out


func _on_node_removed() -> void:
	if _midi_in != null and _port_open:
		_midi_in.close_port()
		_port_open = false


func _on_parameter_changed(param_name: String, _new_value: Variant) -> void:
	if param_name == "port":
		# Reset _prev_port so _cook() reopens on next frame.
		_prev_port = -1


func _get_port_menu() -> PackedStringArray:
	if not ClassDB.class_exists(&"GNMidiIn"):
		return PackedStringArray(["(no native MIDI)"])
	var ports: PackedStringArray = ClassDB.class_call_static(&"GNMidiIn", &"get_port_list")
	if ports.is_empty():
		return PackedStringArray(["(no MIDI devices)"])
	return ports
