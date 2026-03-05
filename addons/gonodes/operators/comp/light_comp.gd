class_name LightCOMP
extends GNCompBase
## Provides a Light3D for 3D scene rendering via RenderTOP.
## Supports Directional, Omni (point), and Spot lights.
## Wraps Godot's native Light3D subclasses.

var _light: Light3D = null
var _current_type: int = -1  # Track which type was last created


func _init() -> void:
	node_type = "light"
	node_description = "Provide a Light3D for 3D rendering."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.COMP, "Light component")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("type",
		PackedStringArray(["Directional", "Omni", "Spot"]), 0, "Light Type", "Light algorithm"))
	# Position (for omni/spot)
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01, "Translate X", "Light X position"))
	add_parameter(GNParameter.create_float("ty", 3.0, null, null, 0.01, "Translate Y", "Light Y position"))
	add_parameter(GNParameter.create_float("tz", 2.0, null, null, 0.01, "Translate Z", "Light Z position"))
	# Rotation
	add_parameter(GNParameter.create_float("rx", -45.0, -90.0, 90.0, 0.1, "Rotate X", "Light pitch (degrees)"))
	add_parameter(GNParameter.create_float("ry", 0.0, -360.0, 360.0, 0.1, "Rotate Y", "Light yaw (degrees)"))
	add_parameter(GNParameter.create_float("rz", 0.0, -360.0, 360.0, 0.1, "Rotate Z", "Light roll (degrees)"))
	# Properties
	add_parameter(GNParameter.create_color("color", Color.WHITE, "Color", "Light colour"))
	add_parameter(GNParameter.create_float("energy", 1.0, 0.0, 16.0, 0.1, "Energy", "Light intensity"))
	add_parameter(GNParameter.create_bool("shadows", true, "Shadows", "Enable shadow casting"))
	# Shadow tuning
	add_parameter(GNParameter.create_float("shadow_bias", 0.1, 0.0, 16.0, 0.01, "Shadow Bias", "Depth bias to reduce shadow acne"))
	add_parameter(GNParameter.create_float("shadow_normal_bias", 1.0, 0.0, 16.0, 0.1, "Shadow Normal Bias", "Normal-based offset to reduce acne on curved surfaces"))
	add_parameter(GNParameter.create_float("shadow_blur", 1.0, 0.0, 10.0, 0.1, "Shadow Blur", "Soft shadow blur radius"))
	add_parameter(GNParameter.create_float("shadow_opacity", 1.0, 0.0, 1.0, 0.05, "Shadow Opacity", "Shadow darkness (0 = invisible, 1 = fully dark)"))
	# Directional shadow mode
	add_parameter(GNParameter.create_enum("dir_shadow_mode",
		PackedStringArray(["Orthogonal", "PSSM 2 Splits", "PSSM 4 Splits"]), 2,
		"Dir Shadow Mode", "Directional light shadow split mode (ignored for Omni/Spot)"))
	# Omni-specific
	add_parameter(GNParameter.create_float("omni_range", 10.0, 0.1, 1000.0, 0.5, "Omni Range", "Point light range"))
	# Spot-specific
	add_parameter(GNParameter.create_float("spot_range", 10.0, 0.1, 1000.0, 0.5, "Spot Range", "Spotlight range"))
	add_parameter(GNParameter.create_float("spot_angle", 45.0, 0.1, 90.0, 0.5, "Spot Angle", "Spotlight cone angle (degrees)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var light_type: int = get_param_value("type")

	# Recreate light if type changed
	if light_type != _current_type:
		if _light != null:
			if _light.get_parent() != null:
				_light.get_parent().remove_child(_light)
			_light.queue_free()
			_light = null

		match light_type:
			0:  # Directional
				_light = DirectionalLight3D.new()
			1:  # Omni
				_light = OmniLight3D.new()
			2:  # Spot
				_light = SpotLight3D.new()

		_light.name = id + "_light"
		_scene_node = _light  # Base class handles cleanup
		_current_type = light_type

	# Update common properties
	_light.light_color = get_param_value("color")
	_light.light_energy = get_param_value("energy")
	_light.shadow_enabled = get_param_value("shadows")

	# Shadow parameters (common to all light types)
	_light.shadow_bias = get_param_value("shadow_bias")
	_light.shadow_normal_bias = get_param_value("shadow_normal_bias")
	_light.shadow_blur = get_param_value("shadow_blur")
	_light.shadow_opacity = get_param_value("shadow_opacity")

	# Directional shadow mode
	if _light is DirectionalLight3D:
		var dir_light: DirectionalLight3D = _light as DirectionalLight3D
		var dir_mode: int = get_param_value("dir_shadow_mode")
		match dir_mode:
			0: dir_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			1: dir_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			2: dir_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS

	# Transform
	_light.position = Vector3(
		get_param_value("tx"), get_param_value("ty"), get_param_value("tz"))
	_light.rotation_degrees = Vector3(
		get_param_value("rx"), get_param_value("ry"), get_param_value("rz"))

	# Type-specific properties
	if _light is OmniLight3D:
		(_light as OmniLight3D).omni_range = get_param_value("omni_range")
	elif _light is SpotLight3D:
		var spot: SpotLight3D = _light as SpotLight3D
		spot.spot_range = get_param_value("spot_range")
		spot.spot_angle = get_param_value("spot_angle")

	return null


## Destroys the scene node and resets light state so the
## next cook recreates the Light3D from scratch.
func destroy_scene_node() -> void:
	super.destroy_scene_node()
	_light = null
	_current_type = -1


## Returns the Light3D node. Called by RenderTOP.
func get_light() -> Light3D:
	return _light


