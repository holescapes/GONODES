class_name CameraCOMP
extends GNCompBase
## Provides a Camera3D for 3D scene rendering via RenderTOP.
## Wraps Godot's Camera3D with GONODES parameter controls.
## RenderTOP calls get_camera() to retrieve and place it in its SubViewport.

var _camera: Camera3D = null


func _init() -> void:
	node_type = "camera"
	node_description = "Provide a Camera3D for 3D rendering."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.COMP, "Camera component")


func _init_parameters() -> void:
	# Position
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01, "Translate X", "Camera X position"))
	add_parameter(GNParameter.create_float("ty", 1.0, null, null, 0.01, "Translate Y", "Camera Y position"))
	add_parameter(GNParameter.create_float("tz", 3.0, null, null, 0.01, "Translate Z", "Camera Z position"))
	# Rotation
	add_parameter(GNParameter.create_float("rx", -15.0, -90.0, 90.0, 0.1, "Rotate X", "Pitch (degrees)"))
	add_parameter(GNParameter.create_float("ry", 0.0, -360.0, 360.0, 0.1, "Rotate Y", "Yaw (degrees)"))
	add_parameter(GNParameter.create_float("rz", 0.0, -360.0, 360.0, 0.1, "Rotate Z", "Roll (degrees)"))
	# Look-at target (optional)
	add_parameter(GNParameter.create_bool("use_look_at", false, "Use Look At", "Use look-at targeting instead of rotation"))
	add_parameter(GNParameter.create_float("look_at_x", 0.0, null, null, 0.01, "Look At X", "Look-at target X"))
	add_parameter(GNParameter.create_float("look_at_y", 0.0, null, null, 0.01, "Look At Y", "Look-at target Y"))
	add_parameter(GNParameter.create_float("look_at_z", 0.0, null, null, 0.01, "Look At Z", "Look-at target Z"))
	# Projection
	add_parameter(GNParameter.create_enum("projection",
		PackedStringArray(["Perspective", "Orthogonal"]), 0, "Projection", "Camera projection mode"))
	add_parameter(GNParameter.create_float("fov", 75.0, 1.0, 179.0, 0.5, "FOV", "Field of view (perspective only)"))
	add_parameter(GNParameter.create_float("ortho_size", 10.0, 0.1, 1000.0, 0.1, "Ortho Size", "Orthographic viewport size"))
	add_parameter(GNParameter.create_float("near", 0.05, 0.001, 100.0, 0.01, "Near Plane", "Near clip distance"))
	add_parameter(GNParameter.create_float("far", 100.0, 1.0, 10000.0, 1.0, "Far Plane", "Far clip distance"))
	# Environment
	add_parameter(GNParameter.create_color("clear_color", Color(0.1, 0.1, 0.1), "Clear Color", "Background clear colour"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = id + "_cam"
		_scene_node = _camera  # Base class handles cleanup

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


## Destroys the scene node and resets camera state so the
## next cook recreates the Camera3D from scratch.
func destroy_scene_node() -> void:
	super.destroy_scene_node()
	_camera = null


## Returns the Camera3D node. Called by RenderTOP.
func get_camera() -> Camera3D:
	return _camera


