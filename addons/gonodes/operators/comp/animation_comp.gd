class_name AnimationCOMP
extends GNCompBase
## AnimationPlayer wrapper for keyframe animation on COMP scene nodes.
##
## Takes a COMP input, attaches an AnimationPlayer to its scene node, and
## drives keyframe animations on transform properties.  Provides built-in
## linear/ease keyframe tracks for translate, rotate, and scale with
## configurable duration, loop mode, and playback speed.
##
## The animation auto-plays each cook so it stays in sync with the cook engine.

var _anim_player: AnimationPlayer = null
var _anim_library: AnimationLibrary = null
var _anim: Animation = null
var _last_anim_hash: int = 0


func _init() -> void:
	node_type = "animation"
	time_dependent = true
	node_description = "AnimationPlayer wrapper for keyframe animation on COMP properties."


func _init_ports() -> void:
	add_input("comp", GNFamily.Type.COMP, false, "Target COMP to animate")
	add_output("out", GNFamily.Type.COMP, "Animated component output")


func _init_parameters() -> void:
	# Playback
	add_parameter(GNParameter.create_bool("active", true, "Active",
		"Enable/disable animation playback"))
	add_parameter(GNParameter.create_float("speed", 1.0, -10.0, 10.0, 0.01,
		"Speed", "Playback speed multiplier"))
	add_parameter(GNParameter.create_float("duration", 2.0, 0.01, 600.0, 0.01,
		"Duration", "Animation length in seconds"))
	add_parameter(GNParameter.create_enum("loop_mode",
		PackedStringArray(["None", "Linear (Loop)", "Ping-Pong"]),
		1, "Loop", "Animation loop mode"))

	# Translate keyframes (start → end)
	add_parameter(GNParameter.create_float("tx_start", 0.0, -100.0, 100.0, 0.01,
		"TX Start", "Translate X at t=0"))
	add_parameter(GNParameter.create_float("tx_end", 0.0, -100.0, 100.0, 0.01,
		"TX End", "Translate X at t=duration"))
	add_parameter(GNParameter.create_float("ty_start", 0.0, -100.0, 100.0, 0.01,
		"TY Start", "Translate Y at t=0"))
	add_parameter(GNParameter.create_float("ty_end", 0.0, -100.0, 100.0, 0.01,
		"TY End", "Translate Y at t=duration"))
	add_parameter(GNParameter.create_float("tz_start", 0.0, -100.0, 100.0, 0.01,
		"TZ Start", "Translate Z at t=0"))
	add_parameter(GNParameter.create_float("tz_end", 0.0, -100.0, 100.0, 0.01,
		"TZ End", "Translate Z at t=duration"))

	# Rotate keyframes (start → end, degrees)
	add_parameter(GNParameter.create_float("rx_start", 0.0, -360.0, 360.0, 0.1,
		"RX Start", "Rotate X at t=0 (degrees)"))
	add_parameter(GNParameter.create_float("rx_end", 0.0, -360.0, 360.0, 0.1,
		"RX End", "Rotate X at t=duration (degrees)"))
	add_parameter(GNParameter.create_float("ry_start", 0.0, -360.0, 360.0, 0.1,
		"RY Start", "Rotate Y at t=0 (degrees)"))
	add_parameter(GNParameter.create_float("ry_end", 360.0, -360.0, 360.0, 0.1,
		"RY End", "Rotate Y at t=duration (degrees)"))
	add_parameter(GNParameter.create_float("rz_start", 0.0, -360.0, 360.0, 0.1,
		"RZ Start", "Rotate Z at t=0 (degrees)"))
	add_parameter(GNParameter.create_float("rz_end", 0.0, -360.0, 360.0, 0.1,
		"RZ End", "Rotate Z at t=duration (degrees)"))

	# Scale keyframes (start → end)
	add_parameter(GNParameter.create_float("sx_start", 1.0, 0.001, 100.0, 0.01,
		"SX Start", "Scale X at t=0"))
	add_parameter(GNParameter.create_float("sx_end", 1.0, 0.001, 100.0, 0.01,
		"SX End", "Scale X at t=duration"))
	add_parameter(GNParameter.create_float("sy_start", 1.0, 0.001, 100.0, 0.01,
		"SY Start", "Scale Y at t=0"))
	add_parameter(GNParameter.create_float("sy_end", 1.0, 0.001, 100.0, 0.01,
		"SY End", "Scale Y at t=duration"))
	add_parameter(GNParameter.create_float("sz_start", 1.0, 0.001, 100.0, 0.01,
		"SZ Start", "Scale Z at t=0"))
	add_parameter(GNParameter.create_float("sz_end", 1.0, 0.001, 100.0, 0.01,
		"SZ End", "Scale Z at t=duration"))


func _cook(inputs: Array[GNData]) -> GNData:
	# Get input COMP's scene node
	var comp_in: GNNode = _get_input_comp_node(inputs, 0)
	if comp_in == null or not (comp_in is GNCompBase):
		return null

	var target_node: Node3D = (comp_in as GNCompBase).get_scene_node()
	if target_node == null:
		return null

	var active: bool = get_param_value("active")
	if not active:
		# Pass through without animating
		return inputs[0] if inputs.size() > 0 else null

	var speed: float = get_param_value("speed")
	var duration: float = maxf(get_param_value("duration"), 0.01)
	var loop_mode_idx: int = get_param_value("loop_mode")

	# Build/rebuild animation if parameters changed
	var anim_hash: int = _compute_anim_hash(duration, loop_mode_idx)
	if _anim == null or anim_hash != _last_anim_hash:
		_build_animation(target_node, duration, loop_mode_idx)
		_last_anim_hash = anim_hash

	# Ensure AnimationPlayer exists on the target
	_ensure_anim_player(target_node)

	# Seek to the correct time based on cook engine time
	var anim_time: float = fmod(elapsed_time * speed, duration)
	if anim_time < 0.0:
		anim_time += duration

	_anim_player.speed_scale = speed
	if not _anim_player.is_playing():
		_anim_player.play(&"gn_anim")
	_anim_player.seek(anim_time, true)

	return inputs[0] if inputs.size() > 0 else null


func _get_input_comp_node(inputs: Array[GNData], port: int) -> GNNode:
	# Walk upstream via the cook engine's network graph
	var eng: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	if eng == null or eng.network == null:
		return null
	var net: GNNetwork = eng.network
	for conn in net.get_input_connections(id):
		if conn.to_port != port:
			continue
		var upstream: GNNode = net.nodes.get(conn.from_node, null)
		if upstream is GNCompBase:
			return upstream
	return null


func _ensure_anim_player(target: Node3D) -> void:
	if _anim_player != null and _anim_player.get_parent() == target:
		return
	# Clean up old player
	if _anim_player != null and is_instance_valid(_anim_player):
		_anim_player.get_parent().remove_child(_anim_player)
		_anim_player.queue_free()
	_anim_player = AnimationPlayer.new()
	_anim_player.name = "GN_AnimComp_%s" % id
	_anim_library = AnimationLibrary.new()
	_anim_player.add_animation_library(&"", _anim_library)
	target.add_child(_anim_player)
	if _anim != null:
		_anim_library.add_animation(&"gn_anim", _anim)


func _build_animation(target: Node3D, duration: float, loop_mode_idx: int) -> void:
	_anim = Animation.new()
	_anim.length = duration
	match loop_mode_idx:
		0: _anim.loop_mode = Animation.LOOP_NONE
		1: _anim.loop_mode = Animation.LOOP_LINEAR
		2: _anim.loop_mode = Animation.LOOP_PINGPONG

	# Position track
	var pos_track: int = _anim.add_track(Animation.TYPE_POSITION_3D)
	_anim.track_set_path(pos_track, ".")
	_anim.position_track_insert_key(pos_track, 0.0, Vector3(
		get_param_value("tx_start"), get_param_value("ty_start"), get_param_value("tz_start")))
	_anim.position_track_insert_key(pos_track, duration, Vector3(
		get_param_value("tx_end"), get_param_value("ty_end"), get_param_value("tz_end")))

	# Rotation track
	var rot_track: int = _anim.add_track(Animation.TYPE_ROTATION_3D)
	_anim.track_set_path(rot_track, ".")
	var rot_start := Vector3(
		deg_to_rad(get_param_value("rx_start")),
		deg_to_rad(get_param_value("ry_start")),
		deg_to_rad(get_param_value("rz_start")))
	var rot_end := Vector3(
		deg_to_rad(get_param_value("rx_end")),
		deg_to_rad(get_param_value("ry_end")),
		deg_to_rad(get_param_value("rz_end")))
	_anim.rotation_track_insert_key(rot_track, 0.0,
		Quaternion.from_euler(rot_start))
	_anim.rotation_track_insert_key(rot_track, duration,
		Quaternion.from_euler(rot_end))

	# Scale track
	var scale_track: int = _anim.add_track(Animation.TYPE_SCALE_3D)
	_anim.track_set_path(scale_track, ".")
	_anim.scale_track_insert_key(scale_track, 0.0, Vector3(
		get_param_value("sx_start"), get_param_value("sy_start"), get_param_value("sz_start")))
	_anim.scale_track_insert_key(scale_track, duration, Vector3(
		get_param_value("sx_end"), get_param_value("sy_end"), get_param_value("sz_end")))

	# Update the library if it exists
	if _anim_library != null:
		if _anim_library.has_animation(&"gn_anim"):
			_anim_library.remove_animation(&"gn_anim")
		_anim_library.add_animation(&"gn_anim", _anim)


func _compute_anim_hash(duration: float, loop_mode: int) -> int:
	# Hash all keyframe parameters to detect changes
	var parts: PackedFloat32Array = PackedFloat32Array([
		duration, float(loop_mode),
		get_param_value("tx_start"), get_param_value("tx_end"),
		get_param_value("ty_start"), get_param_value("ty_end"),
		get_param_value("tz_start"), get_param_value("tz_end"),
		get_param_value("rx_start"), get_param_value("rx_end"),
		get_param_value("ry_start"), get_param_value("ry_end"),
		get_param_value("rz_start"), get_param_value("rz_end"),
		get_param_value("sx_start"), get_param_value("sx_end"),
		get_param_value("sy_start"), get_param_value("sy_end"),
		get_param_value("sz_start"), get_param_value("sz_end"),
	])
	return hash(parts)


func destroy_scene_node() -> void:
	if _anim_player != null and is_instance_valid(_anim_player):
		if _anim_player.get_parent() != null:
			_anim_player.get_parent().remove_child(_anim_player)
		_anim_player.queue_free()
		_anim_player = null
	_anim_library = null
	_anim = null
	super.destroy_scene_node()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _anim_player != null and is_instance_valid(_anim_player):
			if _anim_player.get_parent() != null:
				_anim_player.get_parent().remove_child(_anim_player)
			_anim_player.queue_free()
