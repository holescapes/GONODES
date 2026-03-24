class_name MidiInCHOP
extends GNChopBase
## Receives MIDI input and maps it to CHOP channels.
##
## Output channels (always present):
##   note      — last note number (0-127)
##   velocity  — last note-on velocity (0-127, normalized to 0-1)
##   gate      — 1.0 while a note is held, 0.0 on note-off
##   channel   — MIDI channel (0-15)
##   pitchbend — pitch bend value (-1 to +1)
##   aftertouch — channel pressure (0-1)
##
## CC channels (created on demand):
##   cc:N      — control change N (0-127), value normalized 0-1
##
## Uses Godot's built-in MIDI support (OS.open_midi_inputs / InputEventMIDI).

# ─── State ─────────────────────────────────────────────────────────────────────

## Latest values for the fixed channels.
var _note: float = 0.0
var _velocity: float = 0.0
var _gate: float = 0.0
var _midi_channel: float = 0.0
var _pitchbend: float = 0.0
var _aftertouch: float = 0.0

## CC values: cc_number → normalized float (0-1).
var _cc_values: Dictionary = {}

## Whether MIDI has been opened this session.
var _midi_opened: bool = false

## Device filter (-1 = all devices).
var _device_filter: int = -1


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "midi_in"
	time_dependent = true
	thread_safe = false  # OS MIDI I/O


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "MIDI values as channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("active", true, "Active",
		"Enable/disable MIDI input"))
	add_parameter(GNParameter.create_int("device", -1, -1, 32, "Device",
		"MIDI device index (-1 = all devices)"))
	add_parameter(GNParameter.create_int("channel_filter", -1, -1, 15, "Channel",
		"MIDI channel filter (-1 = all channels, 0-15 = specific)"))
	add_parameter(GNParameter.create_bool("normalize_velocity", true, "Normalize",
		"Normalize velocity and CC to 0.0-1.0 range (otherwise 0-127)"))
	add_parameter(GNParameter.create_bool("reset", false, "Reset",
		"Pulse: clear all stored values"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(_inputs: Array[GNData]) -> GNData:
	var active: bool = get_param_value("active")
	var normalize: bool = get_param_value("normalize_velocity")
	_device_filter = get_param_value("device")

	# Handle reset pulse
	if get_param_value("reset"):
		_note = 0.0
		_velocity = 0.0
		_gate = 0.0
		_midi_channel = 0.0
		_pitchbend = 0.0
		_aftertouch = 0.0
		_cc_values.clear()
		set_param_value("reset", false)

	if active:
		_ensure_midi_open()
	else:
		_close_midi()

	# Build output
	var out: GNChannelData = _prepare_output(60.0)
	var vel_scale: float = 1.0 / 127.0 if normalize else 1.0

	out.set_single_value("note", _note)
	out.set_single_value("velocity", _velocity * vel_scale)
	out.set_single_value("gate", _gate)
	out.set_single_value("channel", _midi_channel)
	out.set_single_value("pitchbend", _pitchbend)
	out.set_single_value("aftertouch", _aftertouch * vel_scale)

	for cc_num in _cc_values:
		out.set_single_value("cc:%d" % cc_num, float(_cc_values[cc_num]) * vel_scale)

	return out


# ═══════════════════════════════════════════════════════════════════════════════
# MIDI Event Handling
# ═══════════════════════════════════════════════════════════════════════════════

## Called by the scene tree's input system — must be connected to the tree.
## We use _unhandled_input so UI controls get first dibs.
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

	_midi_channel = float(midi.channel)

	match midi.message:
		MIDI_MESSAGE_NOTE_ON:
			_note = float(midi.pitch)
			_velocity = float(midi.velocity)
			_gate = 1.0 if midi.velocity > 0 else 0.0  # velocity 0 = note off per MIDI spec
		MIDI_MESSAGE_NOTE_OFF:
			_note = float(midi.pitch)
			_velocity = 0.0
			_gate = 0.0
		MIDI_MESSAGE_CONTROL_CHANGE:
			_cc_values[midi.controller_number] = float(midi.controller_value)
		MIDI_MESSAGE_PITCH_BEND:
			# Godot's pitch_bend is 0-16383, center at 8192
			_pitchbend = (float(midi.pitch) - 8192.0) / 8192.0
		MIDI_MESSAGE_CHANNEL_PRESSURE:
			_aftertouch = float(midi.pressure)

	mark_dirty()


# ═══════════════════════════════════════════════════════════════════════════════
# MIDI Device Management
# ═══════════════════════════════════════════════════════════════════════════════

func _ensure_midi_open() -> void:
	if _midi_opened:
		return
	OS.open_midi_inputs()
	_midi_opened = true
	var devices: PackedStringArray = OS.get_connected_midi_inputs()
	GNLogger.info("MidiInCHOP", "Opened MIDI — %d device(s): %s" % [
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
