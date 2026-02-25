class_name TimerCHOP
extends GNNode
## A versatile timer that counts up in seconds and provides normalized progress.
## Can be started/stopped/reset via input triggers.
## Similar to TouchDesigner's Timer CHOP.

var _running: bool = false
var _elapsed: float = 0.0
var _cached_channel_data: GNChannelData = null
var _prev_start: float = 0.0
var _prev_reset: float = 0.0


func _init() -> void:
	node_type = "timer"
	family = GNFamily.Type.CHOP
	time_dependent = true


func _init_ports() -> void:
	add_input("start", GNFamily.Type.CHOP)
	add_input("reset", GNFamily.Type.CHOP)
	add_output("out", GNFamily.Type.CHOP)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("length", 10.0, 0.0, null, 0.1, "Length (sec)"))
	add_parameter(GNParameter.create_bool("loop", false))
	add_parameter(GNParameter.create_bool("auto_start", true, "Auto Start"))
	add_parameter(GNParameter.create_float("speed", 1.0, 0.0, null, 0.01))


func _cook(inputs: Array[GNData]) -> GNData:
	var start_data: GNChannelData = inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
	var reset_data: GNChannelData = inputs[1] as GNChannelData if inputs.size() > 1 and inputs[1] is GNChannelData else null

	var length_sec: float = get_param_value("length")
	var do_loop: bool = get_param_value("loop")
	var auto: bool = get_param_value("auto_start")
	var spd: float = get_param_value("speed")
	var dt: float = current_delta

	# Handle start trigger
	if start_data != null:
		var sv: float = _get_first_value(start_data)
		if _prev_start < 0.5 and sv >= 0.5:
			_running = true
		_prev_start = sv
	elif auto and not _running and _elapsed == 0.0:
		_running = true

	# Handle reset trigger
	if reset_data != null:
		var rv: float = _get_first_value(reset_data)
		if _prev_reset < 0.5 and rv >= 0.5:
			_elapsed = 0.0
			_running = false
		_prev_reset = rv

	# Advance timer
	if _running:
		_elapsed += dt * spd
		if length_sec > 0.0 and _elapsed >= length_sec:
			if do_loop:
				_elapsed = fmod(_elapsed, length_sec)
			else:
				_elapsed = length_sec
				_running = false

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = 60.0

	_cached_channel_data.set_single_value("timer_seconds", _elapsed)
	var fraction: float = _elapsed / length_sec if length_sec > 0.0 else 0.0
	_cached_channel_data.set_single_value("timer_fraction", clampf(fraction, 0.0, 1.0))
	_cached_channel_data.set_single_value("running", 1.0 if _running else 0.0)
	_cached_channel_data.set_single_value("done", 1.0 if (not _running and _elapsed >= length_sec and length_sec > 0.0) else 0.0)

	return _cached_channel_data


func _get_first_value(data: GNChannelData) -> float:
	for ch_name in data.channels:
		var s: PackedFloat32Array = data.channels[ch_name]
		if s.size() > 0:
			return s[s.size() - 1]
	return 0.0
