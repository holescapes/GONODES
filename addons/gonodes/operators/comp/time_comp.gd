class_name TimeCOMP
extends GNCompBase
## Provides a controllable timeline/time source for the 3D scene.
## Outputs an AnimationPlayer-based scene node with play/pause/speed controls.
## The AnimationPlayer can drive other COMP transforms via expressions.

var _time_node: Node3D = null
var _local_time: float = 0.0
var _playing: bool = true


func _init() -> void:
	node_type = "time"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.COMP, "Time component output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("play", true,
		"Play", "Enable time progression"))
	add_parameter(GNParameter.create_float("speed", 1.0, -10.0, 10.0, 0.01,
		"Speed", "Playback speed multiplier"))
	add_parameter(GNParameter.create_float("range_start", 0.0, 0.0, 3600.0, 0.1,
		"Start", "Timeline range start (seconds)"))
	add_parameter(GNParameter.create_float("range_end", 10.0, 0.1, 3600.0, 0.1,
		"End", "Timeline range end (seconds)"))
	add_parameter(GNParameter.create_bool("loop", true,
		"Loop", "Loop playback within range"))
	add_parameter(GNParameter.create_bool("reset", false,
		"Reset", "Reset time to range start"))
	add_parameter(GNParameter.create_float("set_time", -1.0, -1.0, 3600.0, 0.01,
		"Set Time", "Jump to specific time (-1 = disabled)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var play: bool = get_param_value("play")
	var speed: float = get_param_value("speed")
	var range_start: float = get_param_value("range_start")
	var range_end: float = get_param_value("range_end")
	var do_loop: bool = get_param_value("loop")
	var do_reset: bool = get_param_value("reset")
	var set_time: float = get_param_value("set_time")

	if _time_node == null:
		_time_node = Node3D.new()
		_time_node.name = id + "_time"
		_scene_node = _time_node

	if do_reset:
		_local_time = range_start

	if set_time >= 0.0:
		_local_time = set_time

	if play:
		_local_time += current_delta * speed

	# Handle range bounds
	var duration: float = maxf(range_end - range_start, 0.001)
	if _local_time > range_end:
		if do_loop:
			_local_time = range_start + fmod(_local_time - range_start, duration)
		else:
			_local_time = range_end
	elif _local_time < range_start:
		if do_loop:
			_local_time = range_end - fmod(range_start - _local_time, duration)
		else:
			_local_time = range_start

	# Encode time info in transform for expression access
	# position.x = local_time, position.y = normalized [0-1], position.z = speed
	var normalized: float = (_local_time - range_start) / duration
	_time_node.position = Vector3(_local_time, normalized, speed)

	return _build_comp_data()


func destroy_scene_node() -> void:
	super.destroy_scene_node()
	_time_node = null
	_local_time = 0.0
