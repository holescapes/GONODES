class_name ClipCHOP
extends GNChopBase
## Play back CHOP input with transport controls.
##
## Records the first frame of input and plays it back with start/end
## trimming, speed control, and loop modes.  Trigger restarts playback
## from the start position.
##
## TouchDesigner equivalent: Clip CHOP.

enum LoopMode { NONE, LOOP, PINGPONG }

var _playhead: float = 0.0
var _direction: float = 1.0
var _started: bool = false
var _recorded: GNChannelData = null


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "clip"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Source CHOP to record/play", "In")
	add_output("out", GNFamily.Type.CHOP, "Playback channel data", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("start", 0.0, 0.0, null, 0.01,
		"Start", "Start position (0–1 normalised)"))
	add_parameter(GNParameter.create_float("end", 1.0, 0.0, null, 0.01,
		"End", "End position (0–1 normalised)"))
	add_parameter(GNParameter.create_float("speed", 1.0, -10.0, 10.0, 0.01,
		"Speed", "Playback speed multiplier"))
	add_parameter(GNParameter.create_enum("loop", LoopMode.keys(),
		LoopMode.LOOP, "Loop", "Loop mode"))
	add_parameter(GNParameter.create_bool("play", true,
		"Play", "Enable playback advancement"))
	add_parameter(GNParameter.create_pulse("trigger",
		"Trigger", "Reset playhead to start"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(inputs: Array[GNData]) -> GNData:
	var src := _get_input_chop(inputs, 0)

	# Record input on first valid frame
	if src != null and _recorded == null:
		_recorded = src.duplicate_data() as GNChannelData

	if _recorded == null:
		return null

	var t_start: float = clampf(get_param_value("start"), 0.0, 1.0)
	var t_end: float = clampf(get_param_value("end"), 0.0, 1.0)
	var speed: float = get_param_value("speed")
	var loop_mode: int = get_param_value("loop")
	var playing: bool = get_param_value("play")
	var trigger: bool = get_param_value("trigger")

	if trigger or not _started:
		_playhead = t_start
		_direction = 1.0
		_started = true
		if parameters.has("trigger"):
			parameters["trigger"].value = false

	# Advance playhead
	if playing:
		var range_len := absf(t_end - t_start)
		if range_len < 0.001:
			range_len = 0.001
		var dt_norm := (current_delta * speed * _direction) / range_len
		_playhead += dt_norm * range_len

	# Apply loop mode
	var norm := _apply_loop(_playhead, t_start, t_end, loop_mode)

	# Sample channels at normalised position
	var out := _prepare_output(_recorded.sample_rate)
	for ch_name in _recorded.get_channel_names():
		var ch: PackedFloat32Array = _recorded.get_channel(ch_name)
		if ch.is_empty():
			out.set_single_value(ch_name, 0.0)
			continue
		# Map norm to sample index
		var idx_f := norm * float(ch.size() - 1)
		var idx_lo := clampi(int(idx_f), 0, ch.size() - 1)
		var idx_hi := clampi(idx_lo + 1, 0, ch.size() - 1)
		var frac := idx_f - float(idx_lo)
		var value := lerpf(ch[idx_lo], ch[idx_hi], frac)
		out.set_single_value(ch_name, value)

	return out


func _apply_loop(pos: float, s: float, e: float, mode: int) -> float:
	var range_len := absf(e - s)
	if range_len < 0.001:
		return s
	match mode:
		LoopMode.NONE:
			return clampf(pos, s, e)
		LoopMode.LOOP:
			var local := fmod(pos - s, range_len)
			if local < 0.0:
				local += range_len
			return s + local
		LoopMode.PINGPONG:
			var local := fmod(pos - s, range_len * 2.0)
			if local < 0.0:
				local += range_len * 2.0
			if local > range_len:
				local = range_len * 2.0 - local
				_direction = -1.0
			else:
				_direction = 1.0
			return s + local
	return clampf(pos, s, e)
