class_name PathCOMP
extends GNCompBase
## Moves a COMP along a Path3D using PathFollow3D.
##
## The path curve is defined by control points or loaded from a SOP input.
## The 'progress' parameter (0.0–1.0) controls position along the curve,
## which can be driven by an expression or CHOP via chop()/par() references.
##
## Uses Godot's native Path3D + PathFollow3D.

var _path: Path3D = null
var _follower: PathFollow3D = null
var _curve: Curve3D = null


func _init() -> void:
	node_type = "path"


func _init_ports() -> void:
	add_input("comp_in", GNFamily.Type.COMP, false, "COMP to move along path", "Comp")
	add_input("path_in", GNFamily.Type.SOP, false, "SOP curve defining the path (optional)", "Path SOP")
	add_output("out", GNFamily.Type.COMP, "Path-following component")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("progress", 0.0, 0.0, 1.0, 0.001,
		"Progress", "Position along path (0 = start, 1 = end)"))
	add_parameter(GNParameter.create_bool("loop", true,
		"Loop", "Loop back to start when progress > 1"))
	add_parameter(GNParameter.create_bool("cubic_interp", true,
		"Cubic Interpolation", "Smooth cubic interpolation along curve"))
	add_parameter(GNParameter.create_enum("rotation_mode",
		PackedStringArray(["None", "Y", "XY", "XYZ"]), 3,
		"Rotation Mode", "How the follower orients along the curve"))
	add_parameter(GNParameter.create_bool("tilt", false,
		"Use Tilt", "Apply point tilt values from the curve"))
	# Default curve control points (when no SOP input)
	add_parameter(GNParameter.create_float("p0x", -3.0, null, null, 0.1, "Point 0 X", "Start point X"))
	add_parameter(GNParameter.create_float("p0y", 0.0, null, null, 0.1, "Point 0 Y", "Start point Y"))
	add_parameter(GNParameter.create_float("p0z", 0.0, null, null, 0.1, "Point 0 Z", "Start point Z"))
	add_parameter(GNParameter.create_float("p1x", 0.0, null, null, 0.1, "Point 1 X", "Mid point X"))
	add_parameter(GNParameter.create_float("p1y", 2.0, null, null, 0.1, "Point 1 Y", "Mid point Y"))
	add_parameter(GNParameter.create_float("p1z", -2.0, null, null, 0.1, "Point 1 Z", "Mid point Z"))
	add_parameter(GNParameter.create_float("p2x", 3.0, null, null, 0.1, "Point 2 X", "End point X"))
	add_parameter(GNParameter.create_float("p2y", 0.0, null, null, 0.1, "Point 2 Y", "End point Y"))
	add_parameter(GNParameter.create_float("p2z", 0.0, null, null, 0.1, "Point 2 Z", "End point Z"))
	# Offset from path position
	add_parameter(GNParameter.create_float("ox", 0.0, null, null, 0.01, "Offset X", "Position offset from path"))
	add_parameter(GNParameter.create_float("oy", 0.0, null, null, 0.01, "Offset Y", "Position offset from path"))
	add_parameter(GNParameter.create_float("oz", 0.0, null, null, 0.01, "Offset Z", "Position offset from path"))


func _cook(inputs: Array[GNData]) -> GNData:
	var comp_data = inputs[0] if inputs.size() > 0 else null
	var sop_data: GNGeoData = inputs[1] as GNGeoData if inputs.size() > 1 and inputs[1] is GNGeoData else null

	# Ensure Path3D + PathFollow3D
	_ensure_path()

	# Build curve from SOP or from parameter points
	if sop_data != null and sop_data.has_geometry():
		_build_curve_from_sop(sop_data)
	else:
		_build_curve_from_params()

	# Update follower properties
	var progress: float = get_param_value("progress")
	_follower.loop = get_param_value("loop")
	_follower.cubic_interp = get_param_value("cubic_interp")
	_follower.use_model_front = true

	var rot_mode: int = get_param_value("rotation_mode")
	match rot_mode:
		0: _follower.rotation_mode = PathFollow3D.ROTATION_NONE
		1: _follower.rotation_mode = PathFollow3D.ROTATION_Y
		2: _follower.rotation_mode = PathFollow3D.ROTATION_XY
		3: _follower.rotation_mode = PathFollow3D.ROTATION_XYZ

	_follower.tilt_enabled = get_param_value("tilt")

	# Set progress (ratio maps 0–1 → full curve length)
	_follower.progress_ratio = clampf(progress, 0.0, 1.0)

	# Apply offset
	var offset := Vector3(get_param_value("ox"), get_param_value("oy"), get_param_value("oz"))
	_follower.position += offset

	# If comp input is provided, reparent its scene node under the follower
	if comp_data != null:
		var comp_node: Node3D = _get_upstream_scene_node(0)
		if comp_node != null:
			if comp_node.get_parent() != _follower:
				if comp_node.get_parent() != null:
					comp_node.get_parent().remove_child(comp_node)
				_follower.add_child(comp_node)
			comp_node.position = Vector3.ZERO  # follower handles positioning

	node_warning = ""
	_scene_node = _path
	return comp_data if comp_data != null else _build_comp_data()


func _ensure_path() -> void:
	if _path != null and is_instance_valid(_path):
		return
	_path = Path3D.new()
	_path.name = id + "_path"
	_curve = Curve3D.new()
	_path.curve = _curve

	_follower = PathFollow3D.new()
	_follower.name = id + "_follow"
	_path.add_child(_follower)

	_scene_node = _path


func _build_curve_from_params() -> void:
	_curve.clear_points()
	_curve.add_point(Vector3(get_param_value("p0x"), get_param_value("p0y"), get_param_value("p0z")))
	_curve.add_point(Vector3(get_param_value("p1x"), get_param_value("p1y"), get_param_value("p1z")))
	_curve.add_point(Vector3(get_param_value("p2x"), get_param_value("p2y"), get_param_value("p2z")))
	_path.curve = _curve


func _build_curve_from_sop(geo: GNGeoData) -> void:
	_curve.clear_points()
	var positions := geo.get_positions()
	for pos in positions:
		_curve.add_point(pos)
	_path.curve = _curve


func _get_upstream_scene_node(port: int) -> Node3D:
	var upstream := get_input_node(port)
	if upstream != null and upstream is GNCompBase:
		return (upstream as GNCompBase).get_scene_node()
	return null


func _on_node_removed() -> void:
	if _follower != null and is_instance_valid(_follower):
		_follower.queue_free()
		_follower = null
	if _path != null and is_instance_valid(_path):
		if _path.get_parent() != null:
			_path.get_parent().remove_child(_path)
		_path.queue_free()
		_path = null
