class_name ClockCHOP
extends GNChopBase
## Generates system time, frame number, and BPM-driven beat channels.
## Uses Godot's Engine and Time APIs.


func _init() -> void:
	node_type = "clock"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Clock channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("bpm", 120.0, 1.0, 999.0, 0.1,
		"BPM", "Beats per minute for beat channels"))
	add_parameter(GNParameter.create_bool("time_channels", true, "",
		"Output time / frame / fps channels"))
	add_parameter(GNParameter.create_bool("beat_channels", true, "",
		"Output beat / bar / beat_frac channels"))
	add_parameter(GNParameter.create_int("beats_per_bar", 4, 1, 16,
		"Beats per Bar", "Time signature numerator"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var out: GNChannelData = _prepare_output()
	var bpm: float = get_param_value("bpm")
	var show_time: bool = get_param_value("time_channels")
	var show_beat: bool = get_param_value("beat_channels")
	var bpb: int = maxi(get_param_value("beats_per_bar"), 1)

	if show_time:
		out.set_single_value("seconds", elapsed_time)
		out.set_single_value("frame", float(Engine.get_frames_drawn()))
		out.set_single_value("fps", Engine.get_frames_per_second())
		# Wall-clock hour/minute/second
		var time_dict: Dictionary = Time.get_time_dict_from_system()
		out.set_single_value("hour", float(time_dict["hour"]))
		out.set_single_value("minute", float(time_dict["minute"]))
		out.set_single_value("second", float(time_dict["second"]))

	if show_beat:
		var beats_total: float = elapsed_time * bpm / 60.0
		out.set_single_value("beat", floor(beats_total))
		out.set_single_value("beat_frac", fmod(beats_total, 1.0))
		out.set_single_value("bar", floor(beats_total / bpb))
		out.set_single_value("bar_frac", fmod(beats_total / bpb, 1.0))

	return out
