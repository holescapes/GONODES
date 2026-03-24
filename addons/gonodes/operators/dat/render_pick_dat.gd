class_name RenderPickDAT
extends GNDatBase
## Picks objects from a 3D render by screen-space coordinates.
##
## Given a render TOP/COMP and UV coordinates, performs a ray cast to
## identify which object, face, and world position is under the cursor.
## Outputs a table with pick results.
##
## TouchDesigner equivalent: Render Pick DAT.


func _init() -> void:
	node_type = "render_pick"
	time_dependent = true


func _init_ports() -> void:
	add_input("uv", GNFamily.Type.CHOP, false, "Pick UV coordinates (u, v channels)")
	add_output("out", GNFamily.Type.DAT, "Pick result table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("render_comp", "",
		"Render COMP", "Node ID of the Camera/Render COMP to pick from"))
	add_parameter(GNParameter.create_float("u", 0.5, 0.0, 1.0, 0.001,
		"U", "Horizontal pick coordinate (0–1)"))
	add_parameter(GNParameter.create_float("v", 0.5, 0.0, 1.0, 0.001,
		"V", "Vertical pick coordinate (0–1)"))
	add_parameter(GNParameter.create_float("max_distance", 1000.0, 0.1, 100000.0, 1.0,
		"Max Distance", "Maximum ray cast distance"))
	add_parameter(GNParameter.create_bool("use_input", true,
		"Use Input UV", "Use input CHOP u/v channels instead of parameters"))


func _cook(inputs: Array[GNData]) -> GNData:
	var render_path: String = get_param_value("render_comp")
	var use_input: bool = get_param_value("use_input")
	var max_dist: float = get_param_value("max_distance")

	# Get pick coordinates
	var u: float = get_param_value("u")
	var v: float = get_param_value("v")

	if use_input:
		var in_chop := inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
		if in_chop != null:
			u = in_chop.get_value("u") if in_chop.channels.has("u") else u
			v = in_chop.get_value("v") if in_chop.channels.has("v") else v

	var out := _prepare_table()
	out.set_headers(PackedStringArray([
		"hit", "node_id", "world_x", "world_y", "world_z",
		"normal_x", "normal_y", "normal_z", "distance",
		"face_index", "u", "v"
	]))

	# Try to perform the pick
	var pick_result := _perform_pick(render_path, u, v, max_dist)
	out.append_row(pick_result)

	return out


func _perform_pick(render_path: String, u: float, v: float,
		max_dist: float) -> PackedStringArray:
	# Default: no hit
	var no_hit := PackedStringArray([
		"0", "", "0", "0", "0", "0", "0", "0", "0", "-1",
		"%.4f" % u, "%.4f" % v
	])

	var eng: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	if render_path.is_empty() or eng == null or eng.network == null:
		return no_hit

	var render_node: GNNode = eng.network.nodes.get(render_path, null)
	if render_node == null:
		return no_hit

	# Get the Camera3D and viewport from the render COMP
	var camera: Camera3D = null
	var space_state: PhysicsDirectSpaceState3D = null

	if render_node.has_method("get_scene_node"):
		var sn = render_node.get_scene_node()
		if sn is Camera3D:
			camera = sn
		elif sn != null:
			for child in sn.get_children():
				if child is Camera3D:
					camera = child
					break

	if camera == null:
		return no_hit

	# Get the physics space from the camera's viewport
	var viewport := camera.get_viewport()
	if viewport == null:
		return no_hit

	var world_3d := viewport.find_world_3d()
	if world_3d == null:
		return no_hit

	space_state = world_3d.direct_space_state
	if space_state == null:
		return no_hit

	# Convert UV to screen-space and then to ray
	var vp_size := viewport.get_visible_rect().size
	var screen_pos := Vector2(u * vp_size.x, (1.0 - v) * vp_size.y)
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)

	var query := PhysicsRayQueryParameters3D.create(
		ray_origin, ray_origin + ray_dir * max_dist)
	var result := space_state.intersect_ray(query)

	if result.is_empty():
		return no_hit

	var pos: Vector3 = result.get("position", Vector3.ZERO)
	var normal: Vector3 = result.get("normal", Vector3.ZERO)
	var collider = result.get("collider", null)
	var face_idx: int = result.get("face_index", -1)
	var node_id: String = collider.name if collider != null else ""
	var dist := ray_origin.distance_to(pos)

	return PackedStringArray([
		"1", node_id,
		"%.6f" % pos.x, "%.6f" % pos.y, "%.6f" % pos.z,
		"%.6f" % normal.x, "%.6f" % normal.y, "%.6f" % normal.z,
		"%.4f" % dist, str(face_idx),
		"%.4f" % u, "%.4f" % v
	])
