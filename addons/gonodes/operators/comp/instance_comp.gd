class_name InstanceCOMP
extends GNCompBase
## Massive geometry instancing via Godot's MultiMeshInstance3D.
##
## Takes a template SOP mesh (input 0), an optional point cloud SOP (input 1)
## for per-instance transforms, and an optional MAT (input 2).
##
## If a point cloud is connected, each point becomes an instance origin with
## optional normal alignment and per-point scale via the 'pscale' attribute.
## If no point cloud is connected, a configurable grid/random scatter is used.
##
## This is the high-performance counterpart to CopySOP — instead of baking
## N copies into one ArrayMesh, InstanceCOMP uses MultiMesh which sends one
## draw call to the GPU for all instances.  Handles tens of thousands easily.
##
## Inputs:
##   0 — SOP template mesh (required)
##   1 — SOP point cloud for instance positions (optional — uses grid if absent)
##   2 — MAT material override (optional)
##   3 — CHOP channels for per-instance animation (optional)

var _multi_mesh_instance: MultiMeshInstance3D = null
var _multi_mesh: MultiMesh = null
var _fallback_material: StandardMaterial3D = null


func _init() -> void:
	node_type = "instance"


func _init_ports() -> void:
	add_input("template", GNFamily.Type.SOP, false, "Template SOP geometry")
	add_input("points", GNFamily.Type.SOP, false, "Point cloud for instance placement (optional)")
	add_input("mat_in", GNFamily.Type.MAT, false, "Material override (optional)", "Material")
	add_input("chop_in", GNFamily.Type.CHOP, false, "Per-instance CHOP animation (optional)", "CHOP")
	add_output("out", GNFamily.Type.COMP, "Instanced component")


func _init_parameters() -> void:
	# Grid fallback (when no point cloud input)
	add_parameter(GNParameter.create_int("count", 100, 1, 100000, "Instance Count",
		"Number of instances if no point cloud is connected"))
	add_parameter(GNParameter.create_enum("scatter_mode",
		PackedStringArray(["Grid", "Random"]), 0,
		"Scatter Mode", "Placement mode when no point cloud input"))
	add_parameter(GNParameter.create_float("spacing", 1.0, 0.01, 100.0, 0.1,
		"Spacing", "Grid cell spacing or random spread radius"))
	add_parameter(GNParameter.create_int("seed", 42, 0, 99999, "Seed",
		"Random seed (Random scatter mode)"))

	# Transform
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01, "Translate X", "Group X offset"))
	add_parameter(GNParameter.create_float("ty", 0.0, null, null, 0.01, "Translate Y", "Group Y offset"))
	add_parameter(GNParameter.create_float("tz", 0.0, null, null, 0.01, "Translate Z", "Group Z offset"))
	add_parameter(GNParameter.create_float("rx", 0.0, null, null, 0.1, "Rotate X", "Group rotation X"))
	add_parameter(GNParameter.create_float("ry", 0.0, null, null, 0.1, "Rotate Y", "Group rotation Y"))
	add_parameter(GNParameter.create_float("rz", 0.0, null, null, 0.1, "Rotate Z", "Group rotation Z"))
	add_parameter(GNParameter.create_float("sx", 1.0, null, null, 0.01, "Scale X", "Group scale X"))
	add_parameter(GNParameter.create_float("sy", 1.0, null, null, 0.01, "Scale Y", "Group scale Y"))
	add_parameter(GNParameter.create_float("sz", 1.0, null, null, 0.01, "Scale Z", "Group scale Z"))

	# Per-instance variation
	add_parameter(GNParameter.create_bool("align_to_normal", true, "",
		"Align instances to point normals"))
	add_parameter(GNParameter.create_float("scale_rand", 0.0, 0.0, 1.0, 0.01,
		"Scale Randomize", "Random scale variation (0 = uniform, 1 = ±100%)"))
	add_parameter(GNParameter.create_float("rotation_rand", 0.0, 0.0, 360.0, 1.0,
		"Rotation Randomize", "Random Y-axis rotation per instance (degrees)"))

	# Material fallback
	add_parameter(GNParameter.create_color("albedo_color", Color.WHITE, "Albedo Color",
		"Base colour when no MAT connected"))
	add_parameter(GNParameter.create_float("metallic", 0.0, 0.0, 1.0, 0.01,
		"Metallic", "Metallic factor (fallback material)"))
	add_parameter(GNParameter.create_float("roughness", 0.5, 0.0, 1.0, 0.01,
		"Roughness", "Surface roughness (fallback material)"))

	# Visibility & shadow
	add_parameter(GNParameter.create_bool("visible", true, "Visible", "Show/hide all instances"))
	add_parameter(GNParameter.create_enum("cast_shadow",
		PackedStringArray(["Off", "On", "Double-Sided", "Shadows Only"]), 1,
		"Cast Shadow", "Shadow casting mode"))

	# CHOP animation mapping
	add_parameter(GNParameter.create_enum("chop_map",
		PackedStringArray(["Off", "Position (tx/ty/tz)", "Scale (sx/sy/sz)", "Rotation Y",
			"Color (r/g/b/a)", "Uniform Scale (s)"]), 0,
		"CHOP Map", "How CHOP channels drive per-instance transforms or appearance"))


func _cook(inputs: Array[GNData]) -> GNData:
	var template: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	var pts_geo: GNGeoData = inputs[1] as GNGeoData if inputs.size() > 1 and inputs[1] is GNGeoData else null
	var mat_in: GNMaterialData = inputs[2] as GNMaterialData if inputs.size() > 2 and inputs[2] is GNMaterialData else null
	var chop_in: GNChannelData = inputs[3] as GNChannelData if inputs.size() > 3 and inputs[3] is GNChannelData else null

	if template == null or not template.has_geometry():
		return null

	# ── Ensure MultiMeshInstance3D exists ──
	if _multi_mesh_instance == null:
		_multi_mesh_instance = MultiMeshInstance3D.new()
		_multi_mesh_instance.name = id + "_mmi"
		_multi_mesh = MultiMesh.new()
		_multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
		_multi_mesh_instance.multimesh = _multi_mesh
		_scene_node = _multi_mesh_instance

	# ── Determine if per-instance color is needed ──
	var chop_map: int = get_param_value("chop_map")
	var needs_color := (chop_map == 4)  # Color mode
	var cd_attr := PackedColorArray()
	if pts_geo != null and pts_geo.has_geometry():
		cd_attr = pts_geo.get_point_attrib_color("Cd")
		if not cd_attr.is_empty():
			needs_color = true
	_multi_mesh.use_colors = needs_color

	# ── Assign template mesh ──
	_multi_mesh.mesh = template.mesh

	# ── Collect instance positions ──
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var pscale_attr := PackedFloat32Array()

	if pts_geo != null and pts_geo.has_geometry():
		# Use point cloud positions
		for s in range(pts_geo.mesh.get_surface_count()):
			var arrays: Array = pts_geo.mesh.surface_get_arrays(s)
			if arrays[Mesh.ARRAY_VERTEX] != null:
				positions.append_array(arrays[Mesh.ARRAY_VERTEX])
				if arrays[Mesh.ARRAY_NORMAL] != null:
					normals.append_array(arrays[Mesh.ARRAY_NORMAL])
				else:
					var pad := PackedVector3Array()
					pad.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
					pad.fill(Vector3.UP)
					normals.append_array(pad)
		pscale_attr = pts_geo.get_point_attrib("pscale")
	else:
		# Generate positions from parameters
		var count: int = maxi(get_param_value("count"), 1)
		var spacing: float = get_param_value("spacing")
		var mode: int = get_param_value("scatter_mode")

		if mode == 0:  # Grid
			var side: int = ceili(sqrt(float(count)))
			var offset: float = (side - 1) * spacing * 0.5
			for i in range(count):
				var gx: int = i % side
				var gz: int = i / side
				positions.append(Vector3(gx * spacing - offset, 0.0, gz * spacing - offset))
				normals.append(Vector3.UP)
		else:  # Random
			var rng := RandomNumberGenerator.new()
			rng.seed = get_param_value("seed")
			for _i in range(count):
				positions.append(Vector3(
					rng.randf_range(-spacing, spacing),
					rng.randf_range(-spacing, spacing),
					rng.randf_range(-spacing, spacing)))
				normals.append(Vector3.UP)

	var instance_count: int = positions.size()
	if instance_count == 0:
		return null

	_multi_mesh.instance_count = instance_count

	# ── Per-instance parameters ──
	var align: bool = get_param_value("align_to_normal")
	var scale_rand: float = get_param_value("scale_rand")
	var rot_rand: float = deg_to_rad(get_param_value("rotation_rand"))
	var base_seed: int = get_param_value("seed")

	# CHOP animation data
	var chop_channels: Array[PackedFloat32Array] = []
	if chop_in != null and chop_map > 0:
		var ch_names: PackedStringArray
		match chop_map:
			1: ch_names = PackedStringArray(["tx", "ty", "tz"])
			2: ch_names = PackedStringArray(["sx", "sy", "sz"])
			3: ch_names = PackedStringArray(["ry"])
			4: ch_names = PackedStringArray(["r", "g", "b", "a"])
			5: ch_names = PackedStringArray(["s"])
			_: ch_names = PackedStringArray()
		for cn in ch_names:
			if chop_in.channels.has(cn):
				chop_channels.append(chop_in.channels[cn])
			else:
				chop_channels.append(PackedFloat32Array())

	var rng := RandomNumberGenerator.new()
	rng.seed = base_seed + 12345

	for i in range(instance_count):
		var pos: Vector3 = positions[i]
		var n: Vector3 = normals[i] if i < normals.size() else Vector3.UP

		# Scale
		var s := Vector3.ONE
		if not pscale_attr.is_empty() and i < pscale_attr.size():
			var ps: float = pscale_attr[i]
			s = Vector3(ps, ps, ps)
		if scale_rand > 0.0:
			var factor: float = 1.0 + rng.randf_range(-scale_rand, scale_rand)
			s *= factor

		# Rotation basis
		var basis := Basis.IDENTITY
		if align and n != Vector3.UP and n != Vector3.DOWN:
			var up := Vector3.UP
			var right := up.cross(n).normalized()
			var corrected_up := n.cross(right).normalized()
			basis = Basis(right, corrected_up, n)
		elif align and n == Vector3.DOWN:
			basis = Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.DOWN)

		# Random Y rotation
		if rot_rand > 0.0:
			var angle: float = rng.randf_range(-rot_rand, rot_rand)
			basis = basis * Basis(Vector3.UP, angle)

		# CHOP per-instance offset
		if chop_map == 1 and chop_channels.size() == 3:
			# Position offset
			var ox: float = chop_channels[0][i] if i < chop_channels[0].size() else 0.0
			var oy: float = chop_channels[1][i] if i < chop_channels[1].size() else 0.0
			var oz: float = chop_channels[2][i] if i < chop_channels[2].size() else 0.0
			pos += Vector3(ox, oy, oz)
		elif chop_map == 2 and chop_channels.size() == 3:
			# Scale from CHOP
			var csx: float = chop_channels[0][i] if i < chop_channels[0].size() else 1.0
			var csy: float = chop_channels[1][i] if i < chop_channels[1].size() else 1.0
			var csz: float = chop_channels[2][i] if i < chop_channels[2].size() else 1.0
			s *= Vector3(csx, csy, csz)
		elif chop_map == 3 and chop_channels.size() == 1:
			# Rotation Y from CHOP
			var cry: float = chop_channels[0][i] if i < chop_channels[0].size() else 0.0
			basis = basis * Basis(Vector3.UP, deg_to_rad(cry))
		elif chop_map == 5 and chop_channels.size() == 1:
			# Uniform scale from CHOP
			var cs: float = chop_channels[0][i] if i < chop_channels[0].size() else 1.0
			s *= cs

		basis = basis.scaled(s)
		_multi_mesh.set_instance_transform(i, Transform3D(basis, pos))

		# Per-instance color
		if needs_color:
			var col := Color.WHITE
			if chop_map == 4 and chop_channels.size() >= 3:
				var cr: float = chop_channels[0][i] if i < chop_channels[0].size() else 1.0
				var cg: float = chop_channels[1][i] if i < chop_channels[1].size() else 1.0
				var cb: float = chop_channels[2][i] if i < chop_channels[2].size() else 1.0
				var ca: float = chop_channels[3][i] if chop_channels.size() > 3 and i < chop_channels[3].size() else 1.0
				col = Color(cr, cg, cb, ca)
			elif not cd_attr.is_empty() and i < cd_attr.size():
				col = cd_attr[i]
			_multi_mesh.set_instance_color(i, col)

	# ── Group transform ──
	_multi_mesh_instance.position = Vector3(
		get_param_value("tx"), get_param_value("ty"), get_param_value("tz"))
	_multi_mesh_instance.rotation_degrees = Vector3(
		get_param_value("rx"), get_param_value("ry"), get_param_value("rz"))
	_multi_mesh_instance.scale = Vector3(
		get_param_value("sx"), get_param_value("sy"), get_param_value("sz"))

	# ── Material ──
	if mat_in != null and mat_in.material != null:
		_multi_mesh_instance.material_override = mat_in.material
	else:
		if _fallback_material == null:
			_fallback_material = StandardMaterial3D.new()
		_fallback_material.albedo_color = get_param_value("albedo_color")
		_fallback_material.metallic = get_param_value("metallic")
		_fallback_material.roughness = get_param_value("roughness")
		_multi_mesh_instance.material_override = _fallback_material

	# ── Visibility & Shadow ──
	_multi_mesh_instance.visible = get_param_value("visible")
	var shadow_mode: int = get_param_value("cast_shadow")
	match shadow_mode:
		0: _multi_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		1: _multi_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		2: _multi_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		3: _multi_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

	# Return the template geo (COMPs typically pass geo through)
	return template


func destroy_scene_node() -> void:
	super.destroy_scene_node()
	_multi_mesh_instance = null
	_multi_mesh = null
	_fallback_material = null


func get_multi_mesh_instance() -> MultiMeshInstance3D:
	return _multi_mesh_instance


func render_for_viewer(viewer) -> void:
	if _multi_mesh != null and _multi_mesh.mesh != null:
		var mesh: Mesh = _multi_mesh.mesh
		if mesh is ArrayMesh:
			GNSopBase._ensure_viewer_scene()
			var vp: SubViewport = viewer.get_3d_viewport()
			GNSopBase._reparent_viewer_nodes(vp)
			GNSopBase._viewer_mesh_instance.mesh = mesh
			GNSopBase._viewer_mesh_instance.material_override = \
				_multi_mesh_instance.material_override if _multi_mesh_instance else null
			GNViewerRenderHelpers.apply_orbit_camera(
				GNSopBase._viewer_camera, 45.0, -30.0, 3.0)
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			viewer.set_info_bar("InstanceCOMP")
			viewer.set_info_overlay("%d instances" % _multi_mesh.instance_count)
			return
	var count: int = _multi_mesh.instance_count if _multi_mesh else 0
	viewer.set_info("%d instances" % count, "InstanceCOMP")


## Preview override showing instance count.
func update_preview_control(control: Control) -> void:
	if control is Label:
		var label: Label = control as Label
		if _multi_mesh != null:
			label.text = "%d instances" % _multi_mesh.instance_count
		else:
			label.text = "no instances"
