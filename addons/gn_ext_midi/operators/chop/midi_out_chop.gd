class_name RtMidiOutCHOP
extends GNChopBase
## Send MIDI messages via RtMidi native library.
## Takes channel data input and maps channels to MIDI output:
## - Channels named "n0"-"n127": note on/off (velocity from value)
## - Channels named "cc0"-"cc127": CC messages (value from channel)
## - Channel named "pitch_bend": pitch bend message

var _midi_out: RefCounted = null
var _port_open := false
var _prev_port := -1
var _prev_port_list: PackedStringArray = PackedStringArray()
var _prev_note_states: PackedFloat32Array = PackedFloat32Array()
var _devices_initialized: bool = false


func _init() -> void:
	node_type = "rtmidiout"
	time_dependent = true
	thread_safe = false  # native GNMidiOut I/O
	is_sink = true
	node_description = "Send MIDI via RtMidi native library."
	if ClassDB.class_exists("GNMidiOut"):
		_midi_out = ClassDB.instantiate("GNMidiOut")
	_prev_note_states.resize(128)
	_prev_note_states.fill(0.0)


## MIDI hardware not available on web.
func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux", "android", "ios"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Channel data to send as MIDI", "In")
	add_output("out", GNFamily.Type.CHOP, "Pass-through of input", "Out")


func _init_parameters() -> void:
	var port_param := GNParameter.create_enum("port",
		PackedStringArray(["Port 0"]), 0, "Port",
		"MIDI output port. Populated from connected devices via RtMidi.")
	port_param.dynamic_enum_callback = Callable(self, "_get_port_menu")
	add_parameter(port_param)
	add_parameter(GNParameter.create_int("channel", 0, 0, 15, "MIDI Channel",
		"MIDI channel to send on (0-15)."))
	add_parameter(GNParameter.create_bool("active", true, "Active",
		"Enable/disable MIDI output."))
	add_parameter(GNParameter.create_bool("normalized_input", true, "Normalized Input",
		"Input values are 0.0-1.0 (scale to 0-127). Disable for raw 0-127 input."))


func _cook(inputs: Array[GNData]) -> GNData:
	if not _devices_initialized:
		refresh_dynamic_enums()
		_devices_initialized = true
	if _midi_out == null:
		node_warning = "MIDI requires the native gn_ext_midi library."
		return _get_input_chop(inputs)

	var active: bool = get_param_value("active")
	if not active:
		_deactivate_midi_output()
		return _get_input_chop(inputs)

	var port: int = get_param_value("port")
	var midi_ch: int = get_param_value("channel")
	var normalized: bool = get_param_value("normalized_input")

	_check_port_list_changed()

	# (Re)open port if changed
	if port != _prev_port:
		_midi_out.close_port()
		_port_open = false
		if not _midi_out.open_port(port):
			node_warning = "Failed to open MIDI output port %d." % port
			return _get_input_chop(inputs)
		_port_open = true
		_prev_port = port
		_reset_note_states()

	if not _port_open:
		return _get_input_chop(inputs)

	var in_data: GNChannelData = _get_input_chop(inputs)
	if in_data == null:
		return null

	# Process channel names and send corresponding MIDI
	for ch_name in in_data.channels:
		var val: float = in_data.get_value(ch_name)

		if ch_name.begins_with("n"):
			# Note channel: n0-n127
			var note_str: String = ch_name.substr(1)
			if note_str.is_valid_int():
				var note: int = note_str.to_int()
				if note >= 0 and note < 128:
					var velocity: int = int(val * 127.0) if normalized else int(val)
					velocity = clampi(velocity, 0, 127)

					# Track note on/off transitions
					if velocity > 0 and _prev_note_states[note] == 0.0:
						_midi_out.send_note_on(midi_ch, note, velocity)
					elif velocity == 0 and _prev_note_states[note] > 0.0:
						_midi_out.send_note_off(midi_ch, note, 0)
					_prev_note_states[note] = float(velocity)

		elif ch_name.begins_with("cc"):
			# CC channel: cc0-cc127
			var cc_str: String = ch_name.substr(2)
			if cc_str.is_valid_int():
				var cc_num: int = cc_str.to_int()
				if cc_num >= 0 and cc_num < 128:
					var cc_val: int = int(val * 127.0) if normalized else int(val)
					cc_val = clampi(cc_val, 0, 127)
					_midi_out.send_cc(midi_ch, cc_num, cc_val)

		elif ch_name == "pitch_bend":
			# Pitch bend: input -1..1 (normalized) or 0..16383 (raw)
			var pb: int
			if normalized:
				pb = int((val + 1.0) * 8192.0)
			else:
				pb = int(val)
			pb = clampi(pb, 0, 16383)
			_midi_out.send_pitch_bend(midi_ch, pb)

	return in_data


func _on_node_removed() -> void:
	if _midi_out != null and _port_open:
		_midi_out.close_port()
		_port_open = false


func _on_parameter_changed(param_name: String, _new_value: Variant) -> void:
	if param_name == "port":
		_prev_port = -1


func _deactivate_midi_output() -> void:
	if _midi_out != null and _port_open:
		var midi_ch: int = get_param_value("channel")
		for note in 128:
			if _prev_note_states[note] > 0.0:
				_midi_out.send_note_off(midi_ch, note, 0)
		_midi_out.close_port()
	_port_open = false
	_prev_port = -1


func _reset_note_states() -> void:
	_prev_note_states.fill(0.0)


func _check_port_list_changed() -> void:
	var current_ports: PackedStringArray = ClassDB.class_call_static(&"GNMidiOut", &"get_port_list")
	if current_ports != _prev_port_list:
		_prev_port = -1
	_prev_port_list = current_ports


func _get_port_menu() -> PackedStringArray:
	if not ClassDB.class_exists(&"GNMidiOut"):
		return PackedStringArray(["(no native MIDI)"])
	var ports: PackedStringArray = ClassDB.class_call_static(&"GNMidiOut", &"get_port_list")
	if ports.is_empty():
		return PackedStringArray(["(no MIDI devices)"])
	return ports
