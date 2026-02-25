class_name CameraCOMP
extends GNNode
## Provides a Camera3D for 3D scene rendering via RenderTOP.
## Wraps Godot's Camera3D with GONODES parameter controls.
## RenderTOP calls get_camera() to retrieve and place it in its SubViewport.

var _camera: Camera3D = null


func _init() -> void:
	node_type = "camera"
	family = GNFamily.Type.COMP


func _init_ports() -> void:
	add_output("out", GNFamily.Type.COMP)


func _init_parameters() -> void:
	# Position
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01, "Translate X"))
	add_parameter(GNParameter.create_float("ty", 1.0, null, null, 0.01, "Translate Y"))
	add_parameter(GNParameter.create_float("tz", 3.0, null, null, 0.01, "Translate Z"))
	# Rotation
	add_parameter(GNParameter.create_float("rx", -15.0, -90.0, 90.0, 0.1, "Rotate X"))
	add_parameter(GNParameter.create_float("ry", 0.0, -360.0, 360.0, 0.1, "Rotate Y"))
	add_parameter(GNParameter.create_float("rz", 0.0, -360.0, 360.0, 0.1, "Rotate Z"))
	# Look-at target (optional)
	add_parameter(GNParameter.create_bool("use_look_at", false, "Use Look At"))
	add_parameter(GNParameter.create_float("look_at_x", 0.0, null, null, 0.01, "Look At X"))
	add_parameter(GNParameter.create_float("look_at_y", 0.0, null, null, 0.01, "Look At Y"))
	add_parameter(GNParameter.create_float("look_at_z", 0.0, null, null, 0.01, "Look At Z"))
	# Projection
	add_parameter(GNParameter.create_enum("projection",
		PackedStringArray(["Perspective", "Orthogonal"]), 0, "Projection"))
	add_parameter(GNParameter.create_float("fov", 75.0, 1.0, 179.0, 0.5, "FOV"))
	add_parameter(GNParameter.create_float("ortho_size", 10.0, 0.1, 1000.0, 0.1, "Ortho Size"))
	add_parameter(GNParameter.create_float("near", 0.05, 0.001, 100.0, 0.01, "Near Plane"))
	add_parameter(GNParameter.create_float("far", 100.0, 1.0, 10000.0, 1.0, "Far Plane"))
	# Environment
	add_parameter(GNParameter.create_color("clear_color", Color(0.1, 0.1, 0.1), "Clear Color"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = id + "_cam"

	# Update transform
	_camera.position = Vector3(
		get_param_value("tx"), get_param_value("ty"), get_param_value("tz"))

	var use_look_at: bool = get_param_value("use_look_at")
	if use_look_at:
		var target := Vector3(
			get_param_value("look_at_x"),
			get_param_value("look_at_y"),
			get_param_value("look_at_z"))
		# Only look_at if camera isn't at the target
		if _camera.position.distance_to(target) > 0.001:
			_camera.look_at(target, Vector3.UP)
	else:
		_camera.rotation_degrees = Vector3(
			get_param_value("rx"), get_param_value("ry"), get_param_value("rz"))

	# Update projection
	var proj: int = get_param_value("projection")
	if proj == 0:
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		_camera.fov = get_param_value("fov")
	else:
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.size = get_param_value("ortho_size")

	_camera.near = get_param_value("near")
	_camera.far = get_param_value("far")

	# Return null data — camera provides no downstream data.
	# The actual output is the Camera3D node itself, accessed via get_camera().
	return null


## Returns the Camera3D node. Called by RenderTOP.
func get_camera() -> Camera3D:
	return _camera


## Cleanup
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _camera != null and _camera.get_parent() != null:
			_camera.get_parent().remove_child(_camera)
			_camera.queue_free()
