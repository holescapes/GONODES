class_name MidiInDAT
extends GNDatBase
## Receives MIDI input and logs raw messages as table rows.
##
## Columns: type | channel | note | velocity | cc_num | cc_val | pitchbend | pressure | timestamp
##
## This is the raw-message companion to MidiInCHOP.
## Useful for debugging, triggering logic from specific MIDI events,
## or building custom MIDI routing.

# ─── State ─────────────────────────────────────────────────────────────────────

## Ring buffer of received messages.
var _messages: Array[PackedStringArray] = []
var _max_messages: int = 100

## Whether MIDI has been opened this session.
var _midi_opened: bool = false

## Device filter (-1 = all).
var _device_filter: int = -1


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "midiin"
	time_dependent = true
	node_description = "Log raw MIDI messages into a DAT table."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "MIDI messages table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("active", true, "Active",
		"Enable/disable MIDI input"))
	add_parameter(GNParameter.create_int("device", -1, -1, 32, "Device",
		"MIDI device index (-1 = all)"))
	add_parameter(GNParameter.create_int("channel_filter", -1, -1, 15, "Channel",
		"MIDI channel filter (-1 = all, 0-15 = specific)"))
	add_parameter(GNParameter.create_int("max_rows", 100, 1, 10000, "Max Rows",
		"Maximum stored messages (ring buffer)"))
	add_parameter(GNParameter.create_bool("clear", false, "Clear",
		"Pulse: clear all stored messages"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(_inputs: Array[GNData]) -> GNData:
	var active: bool = get_param_value("active")
	_max_messages = get_param_value("max_rows")
	_device_filter = get_param_value("device")

	# Handle clear pulse
	if get_param_value("clear"):
		_messages.clear()
		set_param_value("clear", false)

	if active:
		_ensure_midi_open()
	else:
		_close_midi()

	# Build output table
	var out: GNTableData = _prepare_table()
	out.is_table = true
	out.has_header = true
	out.set_headers(PackedStringArray([
		"type", "channel", "note", "velocity",
		"cc_num", "cc_val", "pitchbend", "pressure", "timestamp"
	]))

	for row in _messages:
		out.append_row(row)

	return out


# ═══════════════════════════════════════════════════════════════════════════════
# MIDI Event Handling
# ═══════════════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMIDI):
		return
	var midi: InputEventMIDI = event as InputEventMIDI

	# Device filter
	if _device_filter >= 0 and midi.device != _device_filter:
		return

	# Channel filter
	var ch_filter: int = get_param_value("channel_filter")
	if ch_filter >= 0 and midi.channel != ch_filter:
		return

	var row := PackedStringArray()
	row.append(_message_type_name(midi.message))
	row.append(str(midi.channel))

	match midi.message:
		MIDI_MESSAGE_NOTE_ON, MIDI_MESSAGE_NOTE_OFF:
			row.append(str(midi.pitch))
			row.append(str(midi.velocity))
			row.append("")  # cc_num
			row.append("")  # cc_val
			row.append("")  # pitchbend
			row.append("")  # pressure
		MIDI_MESSAGE_CONTROL_CHANGE:
			row.append("")  # note
			row.append("")  # velocity
			row.append(str(midi.controller_number))
			row.append(str(midi.controller_value))
			row.append("")  # pitchbend
			row.append("")  # pressure
		MIDI_MESSAGE_PITCH_BEND:
			row.append("")  # note
			row.append("")  # velocity
			row.append("")  # cc_num
			row.append("")  # cc_val
			row.append(str(midi.pitch))
			row.append("")  # pressure
		MIDI_MESSAGE_CHANNEL_PRESSURE:
			row.append("")  # note
			row.append("")  # velocity
			row.append("")  # cc_num
			row.append("")  # cc_val
			row.append("")  # pitchbend
			row.append(str(midi.pressure))
		_:
			# Fill remaining columns for unknown message types
			for _i in range(6):
				row.append("")

	row.append("%.3f" % elapsed_time)

	_messages.append(row)
	while _messages.size() > _max_messages:
		_messages.pop_front()
	mark_dirty()


## Convert MIDI message enum to human-readable name.
static func _message_type_name(msg: MIDIMessage) -> String:
	match msg:
		MIDI_MESSAGE_NOTE_ON:
			return "note_on"
		MIDI_MESSAGE_NOTE_OFF:
			return "note_off"
		MIDI_MESSAGE_CONTROL_CHANGE:
			return "cc"
		MIDI_MESSAGE_PITCH_BEND:
			return "pitchbend"
		MIDI_MESSAGE_CHANNEL_PRESSURE:
			return "aftertouch"
		MIDI_MESSAGE_PROGRAM_CHANGE:
			return "program"
		_:
			return "0x%02X" % msg


# ═══════════════════════════════════════════════════════════════════════════════
# MIDI Device Management
# ═══════════════════════════════════════════════════════════════════════════════

func _ensure_midi_open() -> void:
	if _midi_opened:
		return
	OS.open_midi_inputs()
	_midi_opened = true
	var devices: PackedStringArray = OS.get_connected_midi_inputs()
	GNLogger.info("MidiInDAT", "Opened MIDI — %d device(s): %s" % [
		devices.size(), ", ".join(devices) if not devices.is_empty() else "(none)"])


func _close_midi() -> void:
	if not _midi_opened:
		return
	OS.close_midi_inputs()
	_midi_opened = false


## Clean up on node removal.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_close_midi()
