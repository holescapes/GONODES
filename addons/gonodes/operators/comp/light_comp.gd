class_name LightCOMP
extends GNCompBase
## Provides a Light3D for 3D scene rendering via RenderTOP.
## Supports Directional, Omni (point), and Spot lights.
## Wraps Godot's native Light3D subclasses.

var _light: Light3D = null
var _current_type: int = -1  # Track which type was last created


func _init() -> void:
	node_type = "light"


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
	add_parameter(GNParameter.create_float("rx", -45.0, null, null, 0.1, "Rotate X", "Light pitch (degrees)"))
	add_parameter(GNParameter.create_float("ry", 0.0, null, null, 0.1, "Rotate Y", "Light yaw (degrees)"))
	add_parameter(GNParameter.create_float("rz", 0.0, null, null, 0.1, "Rotate Z", "Light roll (degrees)"))
	# Properties
	add_parameter(GNParameter.create_color("color", Color.WHITE, "Color", "Light colour"))
	add_parameter(GNParameter.create_float("energy", 1.0, 0.0, 16.0, 0.1, "Energy", "Light intensity"))
	add_parameter(GNParameter.create_bool("shadows", true, "Shadows", "Enable shadow casting"))
	# Shadow tuning
	add_parameter(GNParameter.create_float("shadow_bias", 0.1, 0.0, 16.0, 0.01, "Shadow Bias", "Depth bias to reduce shadow acne"))
	add_parameter(GNParameter.create_float("shadow_normal_bias", 1.0, 0.0, 16.0, 0.1, "Shadow Normal Bias", "Normal-based offset to reduce acne on curved surfaces"))
	add_parameter(GNParameter.create_float("shadow_blur", 1.0, 0.0, 10.0, 0.1, "Shadow Blur", "Soft shadow blur radius"))
	add_parameter(GNParameter.create_float("shadow_opacity", 1.0, 0.0, 1.0, 0.05, "Shadow Opacity", "Shadow darkness (0 = invisible, 1 = fully dark)"))
	# Directional shadow mode (type 0 only)
	var p_dsm := GNParameter.create_enum("dir_shadow_mode",
		PackedStringArray(["Orthogonal", "PSSM 2 Splits", "PSSM 4 Splits"]), 2,
		"Dir Shadow Mode", "Directional light shadow split mode")
	p_dsm.visibility_rule = {"param": "type", "values": [0]}
	add_parameter(p_dsm)
	# Omni-specific (type 1 only)
	var p_or := GNParameter.create_float("omni_range", 10.0, 0.1, 1000.0, 0.5, "Omni Range", "Point light range")
	p_or.visibility_rule = {"param": "type", "values": [1]}
	add_parameter(p_or)
	# Spot-specific (type 2 only)
	var p_sr := GNParameter.create_float("spot_range", 10.0, 0.1, 1000.0, 0.5, "Spot Range", "Spotlight range")
	p_sr.visibility_rule = {"param": "type", "values": [2]}
	add_parameter(p_sr)
	var p_sa := GNParameter.create_float("spot_angle", 45.0, 0.1, 90.0, 0.5, "Spot Angle", "Spotlight cone angle (degrees)")
	p_sa.visibility_rule = {"param": "type", "values": [2]}
	add_parameter(p_sa)


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


func render_for_viewer(viewer) -> void:
	if _light == null:
		viewer.set_info("No light", "LightCOMP")
		return

	var gizmo_mesh: ArrayMesh = _build_light_gizmo()
	var gizmo_mat := StandardMaterial3D.new()
	gizmo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gizmo_mat.albedo_color = _light.light_color
	gizmo_mat.albedo_color.a = 0.9
	gizmo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	GNSopBase._ensure_viewer_scene()
	var vp: SubViewport = viewer.get_3d_viewport()
	GNSopBase._reparent_viewer_nodes(vp)
	GNSopBase._viewer_mesh_instance.mesh = gizmo_mesh
	GNSopBase._viewer_mesh_instance.material_override = gizmo_mat
	GNViewerRenderHelpers.apply_orbit_camera(GNSopBase._viewer_camera, 45.0, -20.0, 5.0)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewer.set_info_bar("LightCOMP")

	var type_names := ["Directional", "Omni", "Spot"]
	var type_name: String = type_names[_current_type] if _current_type >= 0 and _current_type < 3 else "Unknown"
	var energy: float = _light.light_energy
	var shadows: String = "Shadows On" if _light.shadow_enabled else "Shadows Off"
	var extra := ""
	if _light is OmniLight3D:
		extra = "  Range: %.1f" % (_light as OmniLight3D).omni_range
	elif _light is SpotLight3D:
		extra = "  Range: %.1f  Angle: %.0f°" % [(_light as SpotLight3D).spot_range, (_light as SpotLight3D).spot_angle]
	viewer.set_info_overlay("%s  Energy: %.1f\n%s%s" % [type_name, energy, shadows, extra])


## Builds a wireframe gizmo mesh for the current light type.
func _build_light_gizmo() -> ArrayMesh:
	var verts := PackedVector3Array()

	match _current_type:
		0:  # Directional — arrow pointing down -Z
			var shaft_len := 1.5
			var head_len := 0.3
			var head_r := 0.15
			# Central shaft
			verts.append(Vector3.ZERO)
			verts.append(Vector3(0, 0, -shaft_len))
			# Arrow head
			var tip := Vector3(0, 0, -shaft_len - head_len)
			for i in range(8):
				var a: float = TAU * i / 8.0
				var base_pt := Vector3(cos(a) * head_r, sin(a) * head_r, -shaft_len)
				verts.append(base_pt)
				verts.append(tip)
			# Parallel rays
			for offset in [Vector3(0.4, 0, 0), Vector3(-0.4, 0, 0), Vector3(0, 0.4, 0), Vector3(0, -0.4, 0)]:
				verts.append(offset)
				verts.append(offset + Vector3(0, 0, -shaft_len))

		1:  # Omni — wireframe sphere
			var r: float = minf((_light as OmniLight3D).omni_range * 0.15, 1.5)
			var segs := 24
			for ring in range(3):  # XY, XZ, YZ rings
				for i in range(segs):
					var a0: float = TAU * i / segs
					var a1: float = TAU * (i + 1) / segs
					var p0: Vector3
					var p1: Vector3
					match ring:
						0:  # XY
							p0 = Vector3(cos(a0) * r, sin(a0) * r, 0)
							p1 = Vector3(cos(a1) * r, sin(a1) * r, 0)
						1:  # XZ
							p0 = Vector3(cos(a0) * r, 0, sin(a0) * r)
							p1 = Vector3(cos(a1) * r, 0, sin(a1) * r)
						2:  # YZ
							p0 = Vector3(0, cos(a0) * r, sin(a0) * r)
							p1 = Vector3(0, cos(a1) * r, sin(a1) * r)
					verts.append(p0)
					verts.append(p1)
			# Small cross at center
			var c := 0.1
			verts.append_array([Vector3(-c,0,0), Vector3(c,0,0),
				Vector3(0,-c,0), Vector3(0,c,0), Vector3(0,0,-c), Vector3(0,0,c)])

		2:  # Spot — cone
			var spot: SpotLight3D = _light as SpotLight3D
			var range_f: float = minf(spot.spot_range * 0.2, 2.0)
			var angle_rad: float = deg_to_rad(spot.spot_angle)
			var cone_r: float = tan(angle_rad) * range_f
			var segs := 16
			# Cone ring at the end
			for i in range(segs):
				var a0: float = TAU * i / segs
				var a1: float = TAU * (i + 1) / segs
				var p0 := Vector3(cos(a0) * cone_r, sin(a0) * cone_r, -range_f)
				var p1 := Vector3(cos(a1) * cone_r, sin(a1) * cone_r, -range_f)
				verts.append(p0)
				verts.append(p1)
			# Lines from origin to cone edge
			for i in range(4):
				var a: float = TAU * i / 4.0
				verts.append(Vector3.ZERO)
				verts.append(Vector3(cos(a) * cone_r, sin(a) * cone_r, -range_f))

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	if verts.size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	return mesh



