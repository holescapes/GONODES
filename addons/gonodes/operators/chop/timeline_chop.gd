class_name TimelineCHOP
extends GNChopBase
## Independent local timeline — generates time, frame, and progress channels.
##
## Decouples "show time" from the global engine clock.  Multiple TimelineCHOPs
## can run simultaneously at different speeds, ranges, and loop modes.
## Other operators bind to a TimelineCHOP via expressions:
##   chop("timeline1", "time")      → local time in seconds
##   chop("timeline1", "fraction")  → 0–1 normalized progress
##
## TouchDesigner equivalent: Timer CHOP + custom time base.

enum LoopMode { NONE, LOOP, PING_PONG }

var _local_time: float = 0.0
var _pp_dir: float = 1.0
var _was_playing: bool = false


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "timeline"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Timeline channels (time, frame, fraction, playing, speed, looped)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("start", 0.0, 0.0, null, 0.1,
		"Start", "Local start time (seconds)"))
	add_parameter(GNParameter.create_float("end", 10.0, 0.0, null, 0.1,
		"End", "Local end time (seconds)"))
	add_parameter(GNParameter.create_float("speed", 1.0, -10.0, 10.0, 0.01,
		"Speed", "Local speed multiplier"))
	add_parameter(GNParameter.create_enum("loop", PackedStringArray(["None", "Loop", "Ping-Pong"]),
		LoopMode.LOOP, "Loop", "Loop mode at range boundaries"))
	add_parameter(GNParameter.create_bool("play", true,
		"Play", "Enable local playback"))
	add_parameter(GNParameter.create_bool("sync_to_engine", true,
		"Sync to Engine", "When true, local time tracks engine elapsed_time. When false, free-running."))
	add_parameter(GNParameter.create_pulse("trigger",
		"Restart", "Reset local time to start"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(_inputs: Array[GNData]) -> GNData:
	var t_start: float = get_param_value("start")
	var t_end: float = get_param_value("end")
	var spd: float = get_param_value("speed")
	var loop_mode: int = get_param_value("loop")
	var playing: bool = get_param_value("play")
	var sync: bool = get_param_value("sync_to_engine")
	var trigger: bool = get_param_value("trigger")

	# Handle trigger pulse — reset to start
	if trigger:
		_local_time = t_start
		_pp_dir = 1.0
		if parameters.has("trigger"):
			parameters["trigger"].value = false

	var duration := maxf(t_end - t_start, 0.001)
	var looped_flag: float = 0.0

	if sync:
		# Sync mode: derive local time from engine elapsed_time
		var engine_t := elapsed_time * spd
		match loop_mode:
			LoopMode.NONE:
				_local_time = clampf(t_start + engine_t, t_start, t_end)
			LoopMode.LOOP:
				_local_time = t_start + fmod(engine_t, duration)
				if _local_time < t_start:
					_local_time += duration
			LoopMode.PING_PONG:
				var cycle := fmod(engine_t, duration * 2.0)
				if cycle < 0.0:
					cycle += duration * 2.0
				if cycle < duration:
					_local_time = t_start + cycle
				else:
					_local_time = t_end - (cycle - duration)
	else:
		# Free-running mode: advance by delta
		if playing:
			_local_time += current_delta * spd * _pp_dir

			match loop_mode:
				LoopMode.NONE:
					_local_time = clampf(_local_time, t_start, t_end)
				LoopMode.LOOP:
					if _local_time >= t_end:
						_local_time = t_start + fmod(_local_time - t_start, duration)
						looped_flag = 1.0
					elif _local_time < t_start:
						_local_time = t_end - fmod(t_start - _local_time, duration)
						looped_flag = 1.0
				LoopMode.PING_PONG:
					if _local_time >= t_end:
						_pp_dir = -1.0
						_local_time = t_end - fmod(_local_time - t_end, duration)
						looped_flag = 1.0
					elif _local_time < t_start:
						_pp_dir = 1.0
						_local_time = t_start + fmod(t_start - _local_time, duration)
						looped_flag = 1.0

	# Compute outputs
	var fraction := clampf((_local_time - t_start) / duration, 0.0, 1.0)
	var local_frame := roundi(_local_time * 60.0)  # 60 fps default frame number

	var out := _prepare_output(60.0)
	out.set_single_value("time", _local_time)
	out.set_single_value("frame", float(local_frame))
	out.set_single_value("fraction", fraction)
	out.set_single_value("playing", 1.0 if playing else 0.0)
	out.set_single_value("speed", spd)
	out.set_single_value("looped", looped_flag)
	return out
